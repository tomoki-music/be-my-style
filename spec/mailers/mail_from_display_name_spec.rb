require "rails_helper"

# 通知メールの From 表示名をプラットフォームごとに分ける。
# アドレス・送信経路・宛先・件名・Reply-To は変えず、共通のメール(Devise など)は対象外のまま。
RSpec.describe "通知メールの From 表示名", type: :mailer do
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:sender) { create(:customer, name: "送信者", domain_name: "business") }
  let(:recipient) { create(:customer, name: "受信者", domain_name: "business", confirm_mail: true) }
  let(:community) { create(:community, owner_id: sender.id, domain: business_domain) }
  let(:project) { Project.create!(community: community, customer: sender, title: "新サービス企画") }
  let(:project_chat) { ProjectChat.create!(project: project, customer: sender, body: "ラフ案を共有します") }
  let(:post_record) { Post.create!(customer: sender, title: "はじめての投稿", body: "本文") }
  let(:business_env) do
    {
      "BUSINESS_MAIL_SENDER_ENABLED" => "true",
      "BUSINESS_SMTP_ADDRESS" => "sv00000.xserver.jp",
      "BUSINESS_SMTP_USER_NAME" => "info@be-my-style.jp",
      "BUSINESS_SMTP_PASSWORD" => "dummy-password"
    }
  end

  def stub_env(values)
    allow(ENV).to receive(:[]).and_call_original
    values.each { |key, value| allow(ENV).to receive(:[]).with(key).and_return(value) }
  end

  def business_mails
    allow_any_instance_of(Customer).to receive(:business_project_notification_recipient?).and_return(true)
    base = { ac_customer: sender, ps_customer: recipient }
    {
      like_post_mail: CustomerMailer.with(**base, post: post_record).like_post_mail,
      comment_post_mail: CustomerMailer.with(**base, post: post_record, message: double(body: "いいですね")).comment_post_mail,
      business_follow_mail: CustomerMailer.with(**base).business_follow_mail,
      business_request_mail: CustomerMailer.with(**base, community: community).business_request_mail,
      business_accept_mail: CustomerMailer.with(**base, community: community).business_accept_mail,
      business_project_created_mail: CustomerMailer.with(**base, project: project).business_project_created_mail,
      business_project_joined_mail: CustomerMailer.with(**base, project: project).business_project_joined_mail,
      business_project_chat_mail: CustomerMailer.with(**base, project: project, project_chat: project_chat)
                                                .business_project_chat_mail
    }
  end

  def expect_from(mail, name:, address:, label:)
    expect(mail.message).to be_a(Mail::Message), label
    expect(mail[:from].display_names).to eq([name]), label
    expect(mail.from).to eq([address]), label
    expect(mail.reply_to).to be_nil, label
  end

  describe "ビジネスの通知 8 種" do
    context "XServer への切り替えが有効なとき" do
      before { stub_env(business_env) }

      it "表示名が NAKAMA運営事務局、アドレスが info@be-my-style.jp で XServer から送ること" do
        mails = business_mails
        expect(mails.size).to eq 8
        mails.each do |name, mail|
          expect_from(mail, name: "NAKAMA運営事務局", address: "info@be-my-style.jp", label: name.to_s)
          expect(mail.delivery_method.settings).to include(address: "sv00000.xserver.jp", port: 465), name.to_s
        end
      end

      it "宛先・件名は変わらないこと" do
        mail = business_mails[:business_follow_mail]

        expect(mail.to).to eq([recipient.email])
        expect(mail.subject).to eq("あなたのアカウントが「フォロー」されました！")
      end

      it "送信するヘッダーでは表示名がエンコードされ、受信側で NAKAMA運営事務局 と読めること" do
        raw_from = business_mails[:business_follow_mail].encoded[/^From: .*$/].strip

        expect(raw_from).to match(/\AFrom: =\?UTF-8\?/)
        expect(raw_from).to end_with("<info@be-my-style.jp>")
        expect(Mail::Encodings.value_decode(raw_from)).to eq("From: NAKAMA運営事務局 <info@be-my-style.jp>")
      end
    end

    context "切り替えが無効なとき" do
      before { stub_env("BUSINESS_MAIL_SENDER_ENABLED" => nil) }

      it "表示名だけ NAKAMA運営事務局 になり、アドレスと送信経路は従来どおりであること" do
        business_mails.each do |name, mail|
          expect_from(mail, name: "NAKAMA運営事務局", address: "from@example.com", label: name.to_s)
          expect(mail.delivery_method.settings).not_to include(:tls), name.to_s
        end
      end
    end
  end

  it "ビジネスのスレッド投稿通知は表示名が NAKAMA運営事務局 で、アドレスは従来どおりであること" do
    expect(BusinessProjectChatMailer.default[:from]).to eq("NAKAMA運営事務局 <from@example.com>")
  end

  describe "音楽の通知" do
    before { stub_env(business_env) }

    let(:music_recipient) { create(:customer, name: "受信 太郎") }
    let(:music_community) { create(:community, owner_id: music_recipient.id, name: "MMM") }
    let(:event) { create(:event, :event_with_songs, customer: music_recipient, community: music_community) }

    it "CustomerMailer の音楽の通知は表示名が BeMyStyle運営事務局 で、アドレスと送信経路は従来どおりであること" do
      mails = {
        create_follow_mail: CustomerMailer.with(ac_customer: sender, ps_customer: music_recipient).create_follow_mail,
        join_event_mail: CustomerMailer.with(ac_customer: sender, ps_customer: music_recipient, event_id: event.id)
                                       .join_event_mail
      }
      mails.each do |name, mail|
        expect_from(mail, name: "BeMyStyle運営事務局", address: "from@example.com", label: name.to_s)
        expect(mail.delivery_method.settings).not_to include(:tls), name.to_s
      end
      expect(mails[:create_follow_mail].subject).to eq("あなたのアカウントが「フォロー」されました！")
      expect(mails[:create_follow_mail].to).to eq([music_recipient.email])
    end

    it "エントリー依頼・締め切りリマインド・コミュニティからのお知らせも BeMyStyle運営事務局 であること" do
      song = create(:song, event: event)
      join_part = create(:join_part, song: song)
      invitation = create(:entry_invitation, event: event, song: song, join_part: join_part,
                                             customer: music_recipient, requested_by_customer: sender)
      reminder = EventDeadlineReminder.create!(event: event, kind: "entry", channel: "mail")
      delivery = reminder.deliveries.create!(customer: music_recipient, status: :sending)
      message = EventDeadlineReminders::MessageBuilder.call(event: event, kind: "entry", sent_at: Time.current)

      mails = {
        entry_invitation: EntryInvitationMailer.invite(invitation),
        deadline_reminder: EventDeadlineReminderMailer.with(delivery: delivery, message: message).remind,
        community_contact: ContactMailer.send_mail("お知らせ", "本文", music_community, Customer.where(id: music_recipient.id))
      }
      mails.each do |name, mail|
        expect_from(mail, name: "BeMyStyle運営事務局", address: "from@example.com", label: name.to_s)
      end
      expect(mails[:community_contact].bcc).to eq([music_recipient.email])
    end
  end

  describe "対象外のメール" do
    it "Devise・学習・管理者向けのメールは表示名を変えないこと" do
      reset = Devise::Mailer.reset_password_instructions(recipient, "dummy-token")

      expect(reset[:from].display_names.compact).not_to include("NAKAMA運営事務局", "BeMyStyle運営事務局")
      expect(LearningMailer.default[:from]).to eq("管理人より<from@example.com>")
      expect(AdminNotificationMailer.default[:from]).to eq("管理人より<from@example.com>")
    end
  end
end
