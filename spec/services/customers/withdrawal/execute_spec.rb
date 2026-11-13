require "rails_helper"

RSpec.describe Customers::Withdrawal::Execute do
  include ActiveSupport::Testing::TimeHelpers

  let(:now) { Time.zone.parse("2026-11-13 12:00") }
  let(:organizer) { create(:customer) }
  let(:community_owner) { create(:customer) }
  let(:community) { create(:community, owner_id: community_owner.id) }
  let(:customer) do
    create(:customer, name: "山田花子", introduction: "ギター弾きです", url: "https://example.com/me",
                      favorite_artist1: "好きなバンド", job: "会社員", birthday: Date.new(1990, 1, 1))
  end

  around { |example| travel_to(now) { example.run } }

  def create_event(start_at:, host: organizer)
    event = build(:event, customer: host, community: community,
                          event_start_time: start_at, event_end_time: start_at + 3.hours,
                          event_entry_deadline: start_at - 1.day)
    event.songs << build(:song, event: event)
    event.save!
    event
  end

  def entry_for(event, member = customer)
    join_part = create(:join_part, song: event.songs.first)
    create(:join_part_customer, customer: member, join_part: join_part)
  end

  describe "退会の確定" do
    it "ログインできない状態にし、プロフィールを消して名前・メールアドレスを置き換える" do
      original_email = customer.email
      original_encrypted_password = customer.encrypted_password

      result = described_class.call(customer)

      expect(result).to be_withdrawn
      customer.reload
      expect(customer.withdrawn_at).to eq(now)
      expect(customer.is_deleted).to be(true)
      expect(customer.name).to eq("退会済みユーザー")
      expect(customer.email).not_to eq(original_email)
      expect(customer.email).to end_with("@withdrawn.invalid")
      expect(customer.encrypted_password).not_to eq(original_encrypted_password)
      expect(customer.valid_password?("password")).to be(false)
      expect(customer.introduction).to be_nil
      expect(customer.url).to be_nil
      expect(customer.favorite_artist1).to be_nil
      expect(customer.job).to be_nil
      expect(customer.birthday).to be_nil
      expect(customer.confirm_mail).to be(false)
      expect(customer.active_for_authentication?).to be(false)
      expect(customer.notifiable?).to be(false)
    end

    it "パスワード再設定・メール確認のトークンとログイン保持を消す" do
      raw_reset_token = customer.send(:set_reset_password_token)
      customer.update_columns(confirmation_token: "confirm-token", unconfirmed_email: "new@example.com", remember_created_at: now)

      described_class.call(customer)

      customer.reload
      expect(customer.reset_password_token).to be_nil
      expect(customer.confirmation_token).to be_nil
      expect(customer.unconfirmed_email).to be_nil
      expect(customer.remember_created_at).to be_nil
      expect(Customer.with_reset_password_token(raw_reset_token)).to be_nil
    end

    it "パート・ジャンル・フォロー関係・自分宛ての通知・会員メモを消し、自分が起こした通知は相手の履歴として残す" do
      other = create(:customer)
      part = Part.create!(name: "ギター")
      customer.parts << part
      Relationship.create!(follower_id: customer.id, followed_id: other.id)
      Relationship.create!(follower_id: other.id, followed_id: customer.id)
      received = Notification.create!(visitor_id: other.id, visited_id: customer.id, action: "follow")
      sent = Notification.create!(visitor_id: customer.id, visited_id: other.id, action: "follow")
      customer.create_member_profile!(admin_memo: "メモ")

      described_class.call(customer)

      expect(CustomerPart.where(customer_id: customer.id)).to be_empty
      expect(Relationship.where(follower_id: customer.id).or(Relationship.where(followed_id: customer.id))).to be_empty
      expect(Notification.unscoped.exists?(received.id)).to be(false)
      expect(Notification.unscoped.exists?(sent.id)).to be(true)
      expect(MemberProfile.where(customer_id: customer.id)).to be_empty
      expect(Part.exists?(part.id)).to be(true)
    end

    it "活動報告・コメント・チャット・過去のイベント参加は共有履歴として残す" do
      past_event = create_event(start_at: now - 10.days)
      past_entry = entry_for(past_event)
      other = create(:customer)
      activity = create(:activity, customer: customer)
      comment = create(:comment, customer: other, activity: activity)
      chat_message = create(:chat_message, customer: customer, chat_room: create(:chat_room))

      described_class.call(customer)

      expect(JoinPartCustomer.exists?(past_entry.id)).to be(true)
      expect(Activity.exists?(activity.id)).to be(true)
      expect(Comment.exists?(comment.id)).to be(true)
      expect(ChatMessage.exists?(chat_message.id)).to be(true)
      expect(Customer.exists?(customer.id)).to be(true)
      expect(Event.exists?(past_event.id)).to be(true)
    end

    it "取消期限前の開催前イベントのエントリーを取り消し、ほかの人のエントリーは残す" do
      upcoming_event = create_event(start_at: now + 30.days)
      own_entry = entry_for(upcoming_event)
      other_entry = entry_for(upcoming_event, create(:customer))

      described_class.call(customer)

      expect(JoinPartCustomer.exists?(own_entry.id)).to be(false)
      expect(JoinPartCustomer.exists?(other_entry.id)).to be(true)
    end

    it "承認待ちの参加申請を取り下げ、承認待ちのエントリー依頼を送信対象外にする" do
      permit = create(:permit, customer: customer, community: community)
      # entry_invitation ファクトリ既定のイベントは owner_id=1 のコミュニティを作るため、このテストのコミュニティを使う。
      invitation_event = create_event(start_at: now + 30.days)
      invitation = create(:entry_invitation, customer: customer, status: :pending, event_for_invitation: invitation_event)
      delivered = create(:entry_invitation, customer: customer, status: :delivered, event_for_invitation: invitation_event)

      expect(described_class.call(customer)).to be_withdrawn

      expect(Permit.exists?(permit.id)).to be(false)
      expect(invitation.reload).to be_skipped
      expect(invitation.failure_reason).to eq(EntryInvitations::Sender::WITHDRAWN_FAILURE_REASON)
      expect(delivered.reload).to be_delivered
    end

    it "ほかに管理できる人がいるコミュニティの運営者権限は外す" do
      CommunityOwner.create!(customer: customer, community: community)

      expect(described_class.call(customer)).to be_withdrawn
      expect(CommunityOwner.where(customer_id: customer.id)).to be_empty
      expect(community.reload.owner_id).to eq(community_owner.id)
    end

    it "歌唱・演奏診断を公開表示(ランキング等)の対象から外し、音声ファイルを削除する(診断の行は集計のため残す)" do
      diagnosis = create(:singing_diagnosis, customer: customer, ranking_opt_in: true)
      expect(diagnosis.audio_file).to be_attached

      described_class.call(customer)

      diagnosis.reload
      expect(diagnosis.ranking_opt_in).to be(false)
      expect(diagnosis.audio_file).not_to be_attached
      expect(SingingDiagnosis.exists?(diagnosis.id)).to be(true)
    end

    it "プロフィール画像のファイルを削除する" do
      customer.profile_image.attach(io: StringIO.new("image"), filename: "me.png", content_type: "image/png")
      blob_id = customer.profile_image.blob.id

      described_class.call(customer)

      expect(customer.reload.profile_image).not_to be_attached
      expect(ActiveStorage::Blob.exists?(blob_id)).to be(false)
    end

    it "同じメールアドレスで新しく登録できる(元のアドレスを残さない)" do
      email = customer.email
      described_class.call(customer)

      new_account = create(:customer, email: email)

      expect(new_account).to be_persisted
      expect(new_account.id).not_to eq(customer.id)
    end
  end

  describe "二重実行" do
    it "2回目は何も変えずに already_withdrawn を返す" do
      described_class.call(customer)
      snapshot = customer.reload.attributes

      result = described_class.call(Customer.find(customer.id))

      expect(result).to be_already_withdrawn
      expect(customer.reload.attributes).to eq(snapshot)
    end
  end

  describe "途中で失敗した場合" do
    it "トランザクションを巻き戻し、何も変わらない(エントリー・フォロー・ログインも元のまま)" do
      upcoming_event = create_event(start_at: now + 30.days)
      entry = entry_for(upcoming_event)
      other = create(:customer)
      Relationship.create!(follower_id: customer.id, followed_id: other.id)
      original_email = customer.email
      allow_any_instance_of(described_class).to receive(:anonymize_account!).and_raise(ActiveRecord::StatementInvalid, "boom")

      expect { described_class.call(customer) }.to raise_error(ActiveRecord::StatementInvalid)

      customer.reload
      expect(customer.withdrawn_at).to be_nil
      expect(customer.is_deleted).to be(false)
      expect(customer.email).to eq(original_email)
      expect(customer.active_for_authentication?).to be(true)
      expect(JoinPartCustomer.exists?(entry.id)).to be(true)
      expect(Relationship.where(follower_id: customer.id)).to exist
    end

    it "ファイル削除に失敗しても退会は成立し、再実行で削除できる" do
      customer.profile_image.attach(io: StringIO.new("image"), filename: "me.png", content_type: "image/png")
      purge_calls = 0
      allow_any_instance_of(ActiveStorage::Attached::One).to receive(:purge).and_wrap_original do |original, *args|
        purge_calls += 1
        raise StandardError, "storage down" if purge_calls == 1

        original.call(*args)
      end

      expect(described_class.call(customer)).to be_withdrawn
      expect(customer.reload).to be_withdrawn
      expect(customer.profile_image).to be_attached

      expect(Customers::Withdrawal::PurgeFiles.call(customer)).to eq(0)
      expect(customer.reload.profile_image).not_to be_attached
    end
  end

  describe "退会を確定できない場合" do
    def expect_blocked(key)
      result = described_class.call(customer)

      expect(result).to be_blocked
      expect(result.plan.blockers.map(&:key)).to include(key)
      expect(customer.reload.withdrawn_at).to be_nil
      expect(customer.is_deleted).to be(false)
    end

    it "オーナーのコミュニティがあると止める(所有権を他人へ移さない)" do
      create(:community, owner_id: customer.id)

      expect_blocked(:owned_communities)
    end

    it "ほかに管理できる人がいないコミュニティの運営者だと止める" do
      solo = create(:community, owner_id: nil)
      CommunityOwner.create!(customer: customer, community: solo)

      expect_blocked(:sole_manager_communities)
      expect(CommunityOwner.where(customer_id: customer.id, community_id: solo.id)).to exist
    end

    it "主催している終了前のイベントがあると止める" do
      create_event(start_at: now + 30.days, host: customer)

      expect_blocked(:hosted_events)
    end

    it "終了したイベントの主催者であることは止めない" do
      create_event(start_at: now - 30.days, host: customer)

      expect(described_class.call(customer)).to be_withdrawn
    end

    it "取消期限(開始7日前)を過ぎたエントリーがあると止め、エントリーを消さない" do
      soon_event = create_event(start_at: now + 3.days)
      entry = entry_for(soon_event)

      expect_blocked(:locked_entries)
      expect(JoinPartCustomer.exists?(entry.id)).to be(true)
    end

    it "Stripe で契約中の有料プランがあると止める" do
      create(:subscription, customer: customer, status: "active", plan: "core")

      expect_blocked(:active_subscription)
    end

    it "管理画面で付与しただけのプラン(Stripe 契約なし)は止めない" do
      create(:subscription, customer: customer, status: "active", plan: "core", stripe_customer_id: nil, stripe_subscription_id: nil)

      expect(described_class.call(customer)).to be_withdrawn
    end

    it "学習サービスの生徒がいると止める" do
      LearningStudent.create!(customer: customer, name: "生徒", status: "active", main_part: LearningCatalog::PARTS.keys.first)

      expect_blocked(:learning_students)
    end

    it "システム管理者のアカウントは止める" do
      customer.update_columns(is_owner: Customer.is_owners[:admin])

      expect_blocked(:system_admin)
    end
  end

  describe "旧方式の退会(管理画面で is_deleted だけを立てた会員)" do
    let(:other_legacy) { create(:customer, name: "別の旧方式の人", email: "other-legacy@example.com") }

    before do
      customer.update_columns(is_deleted: true)
      other_legacy.update_columns(is_deleted: true)
    end

    def expect_still_legacy_deleted(name: "山田花子", email:)
      customer.reload
      expect(customer.is_deleted).to be(true)
      expect(customer.withdrawn_at).to be_nil
      expect(customer.name).to eq(name)
      expect(customer.email).to eq(email)
      expect(customer.active_for_authentication?).to be(false)
      expect(Customer.notifiable.exists?(customer.id)).to be(false)
    end

    it "既定(本人の退会と同じ呼び方)では処理済みとして扱い、何も変えない" do
      snapshot = customer.reload.attributes

      result = described_class.call(customer)

      expect(result).to be_already_withdrawn
      expect(customer.reload.attributes).to eq(snapshot)
    end

    it "include_legacy_deleted: true のときは、通常の退会と同じく個人情報の削除・置き換えを行う" do
      result = described_class.call(customer, include_legacy_deleted: true)

      expect(result).to be_withdrawn
      customer.reload
      expect(customer.withdrawn_at).to eq(now)
      expect(customer.is_deleted).to be(true)
      expect(customer.name).to eq(Customer::WITHDRAWN_NAME)
      expect(customer.email).to end_with("@#{WithdrawnMailInterceptor::DOMAIN}")
      expect(customer.introduction).to be_nil
      expect(customer.valid_password?("password")).to be(false)
    end

    it "処理の途中も退会扱い(ログイン不可・通知の対象外)のまま変えない" do
      states = []
      allow_any_instance_of(described_class).to receive(:remove_personal_data!).and_wrap_original do |original, *args|
        states << [Customer.find(customer.id).is_deleted, Customer.notifiable.exists?(customer.id)]
        original.call(*args)
      end

      described_class.call(customer, include_legacy_deleted: true)

      expect(states).to eq([[true, false]])
    end

    it "止める理由があれば、旧方式の退会状態のまま何も変えない" do
      original_email = customer.email
      create(:community, owner_id: customer.id)

      result = described_class.call(customer, include_legacy_deleted: true)

      expect(result).to be_blocked
      expect_still_legacy_deleted(email: original_email)
    end

    it "途中で失敗しても、旧方式の退会状態のまま何も変えない" do
      original_email = customer.email
      other = create(:customer)
      Relationship.create!(follower_id: other.id, followed_id: customer.id)
      allow_any_instance_of(described_class).to receive(:anonymize_account!).and_raise(ActiveRecord::StatementInvalid, "boom")

      expect { described_class.call(customer, include_legacy_deleted: true) }.to raise_error(ActiveRecord::StatementInvalid)

      expect_still_legacy_deleted(email: original_email)
      expect(Relationship.where(followed_id: customer.id)).to exist
    end

    it "退会の手続きが済んだ会員は、include_legacy_deleted: true でも処理済みとして扱う" do
      described_class.call(customer, include_legacy_deleted: true)
      snapshot = customer.reload.attributes

      result = described_class.call(Customer.find(customer.id), include_legacy_deleted: true)

      expect(result).to be_already_withdrawn
      expect(customer.reload.attributes).to eq(snapshot)
    end

    it "指定した会員だけを処理し、ほかの旧方式の会員には触れない" do
      described_class.call(customer, include_legacy_deleted: true)

      other_legacy.reload
      expect(other_legacy.name).to eq("別の旧方式の人")
      expect(other_legacy.email).to eq("other-legacy@example.com")
      expect(other_legacy.withdrawn_at).to be_nil
    end
  end
end
