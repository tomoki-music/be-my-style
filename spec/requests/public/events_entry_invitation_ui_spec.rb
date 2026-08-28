require 'rails_helper'

# 楽曲表へ統合したエントリー依頼UI(Phase 2)。
# - 主催者向け: 各曲・各パート欄に候補(アバター+緑丸・氏名・プロフィールリンク・状態バッジ・
#   チェックボックス)を表示。見出し・説明・送信ボタンと確認画面へのGETフォームは
#   楽曲表の外(横スクロール領域外)の1行にだけ置く。
# - 一般ユーザー: 「演奏したことのある人」の氏名とプロフィールリンクのみ。
RSpec.describe "Public::Events#show エントリー依頼UI(楽曲表統合)", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:community) { FactoryBot.create(:community) }
  let(:owner) { FactoryBot.create(:customer, :customer_with_parts, name: "オーナー") }
  let(:admin) { FactoryBot.create(:customer, is_owner: :admin) }
  let(:manager) { FactoryBot.create(:customer, :customer_with_parts, name: "共同オーナー") }
  let(:general_member) { FactoryBot.create(:customer, name: "一般ユーザー") }
  let(:experienced_customer) { FactoryBot.create(:customer, name: "経験太郎") }

  let(:past_event) do
    FactoryBot.create(
      :event, :event_with_songs, community: community, customer: owner,
      event_start_time: 3.days.ago, event_end_time: 2.days.ago, event_entry_deadline: 4.days.ago
    )
  end
  let(:current_event) do
    FactoryBot.create(
      :event, :event_with_songs, community: community, customer: owner,
      event_start_time: 2.days.from_now, event_end_time: 3.days.from_now, event_entry_deadline: 1.day.from_now
    )
  end
  let(:past_song) { FactoryBot.create(:song, event: past_event, song_name: "共通曲", artist_name: "共通アーティスト") }
  let(:current_song) { FactoryBot.create(:song, event: current_event, song_name: "共通曲", artist_name: "共通アーティスト") }
  let(:past_part) { FactoryBot.create(:join_part, song: past_song, join_part_name: "Vocal") }
  let(:current_part) { FactoryBot.create(:join_part, song: current_song, join_part_name: "Vocal") }

  before do
    community.update!(owner_id: owner.id)
    CommunityOwner.find_or_create_by!(customer: owner, community: community)
    CommunityOwner.find_or_create_by!(customer: manager, community: community)
    [owner, manager, general_member, experienced_customer].each do |c|
      CommunityCustomer.find_or_create_by!(customer: c, community: community)
    end
    current_part
    FactoryBot.create(:join_part_customer, join_part: past_part, customer: experienced_customer)
  end

  def show_event
    get public_event_path(current_event)
  end

  def doc
    Nokogiri::HTML(response.body)
  end

  describe "権限者(オーナー)" do
    before do
      sign_in owner
      show_event
    end

    it "送信フォーム・見出し・送信ボタンが1つずつ、フォームの入れ子は無い" do
      expect(doc.css("#entry-invitation-form").size).to eq 1
      expect(doc.css(".js-entry-invitation-submit").size).to eq 1
      expect(response.body).to include "演奏経験者へエントリーをお願いする"
      expect(doc.css("form form").size).to eq 0
    end

    it "候補チェックボックスは楽曲表内にあり、form属性で外側フォームへ紐付く" do
      checkbox = doc.at_css(".js-entry-invitation-checkbox")
      expect(checkbox["name"]).to eq "targets[]"
      expect(checkbox["value"]).to eq "#{current_song.id}:#{current_part.id}:#{experienced_customer.id}"
      expect(checkbox["id"]).to eq "entry_invitation_target_#{current_song.id}_#{current_part.id}_#{experienced_customer.id}"
      expect(checkbox["form"]).to eq "entry-invitation-form"
    end

    it "全ての targets[] チェックボックスが外側フォームへ紐付く" do
      doc.css("input[name='targets[]']").each do |input|
        expect(input["form"]).to eq "entry-invitation-form"
      end
    end

    it "checkbox の id と label の for が一致し、アバターは label 内・プロフィールリンクは label 外" do
      candidate = doc.at_css(".entry-invitation-candidate")
      checkbox = candidate.at_css(".js-entry-invitation-checkbox")
      label = candidate.at_css("label.entry-invitation-candidate__label")

      expect(label["for"]).to eq checkbox["id"]
      expect(label.at_css(".avatar-with-badge")).to be_present
      expect(label.text).to include "経験太郎"
      expect(label.at_css("a")).to be_nil

      profile_link = candidate.at_css("a.entry-invitation-candidate__profile")
      expect(profile_link["href"]).to eq public_customer_path(experienced_customer)
      expect(profile_link.ancestors("label")).to be_empty
    end

    it "checkbox の id と target token はページ内で一意" do
      ids = doc.css(".js-entry-invitation-checkbox").map { |cb| cb["id"] }
      tokens = doc.css("input[name='targets[]']").map { |cb| cb["value"] }
      expect(ids).to eq ids.uniq
      expect(tokens).to eq tokens.uniq
    end

    it "独立した候補者一覧パネルは存在しない" do
      expect(response.body).not_to include "entry-invitation-panel"
    end
  end

  it "アクティブな候補には緑丸が付く" do
    sign_in owner
    show_event
    expect(doc.at_css(".entry-invitation-candidate .avatar-active-dot")).to be_nil

    experienced_customer.update!(last_active_at: Time.current)
    show_event
    expect(doc.at_css(".entry-invitation-candidate .avatar-active-dot")).to be_present
  end

  describe "募集・依頼状態" do
    it "24時間以内に依頼済みは checkbox 無効・バッジ「依頼済み」" do
      FactoryBot.create(:entry_invitation,
        event: current_event, song: current_song, join_part: current_part,
        customer: experienced_customer, requested_by_customer: owner, sent_at: 1.hour.ago)
      sign_in owner
      show_event

      candidate = doc.at_css(".entry-invitation-candidate")
      expect(candidate.at_css(".js-entry-invitation-checkbox")).to be_nil
      expect(candidate.text).to include "依頼済み"
    end

    it "24時間の再送禁止期間を過ぎた依頼済みは checkbox 有効・バッジ「再依頼可」" do
      FactoryBot.create(:entry_invitation,
        event: current_event, song: current_song, join_part: current_part,
        customer: experienced_customer, requested_by_customer: owner, sent_at: 2.days.ago)
      sign_in owner
      show_event

      candidate = doc.at_css(".entry-invitation-candidate")
      expect(candidate.at_css(".js-entry-invitation-checkbox")).to be_present
      expect(candidate.text).to include "再依頼可"
    end

    it "募集終了(現役参加者あり)のパートは経験者を表示しつつ checkbox 無し・バッジ「募集終了」" do
      # current_part に別の現役参加者を入れて募集終了にする。経験太郎は依頼候補として残る。
      joiner = FactoryBot.create(:customer, name: "参加済次郎")
      CommunityCustomer.find_or_create_by!(customer: joiner, community: community)
      FactoryBot.create(:join_part_customer, join_part: current_part, customer: joiner)
      sign_in owner
      show_event

      candidate = doc.css(".entry-invitation-candidate").find { |c| c.text.include?("経験太郎") }
      expect(candidate).to be_present
      expect(candidate.at_css(".js-entry-invitation-checkbox")).to be_nil
      expect(candidate.text).to include "募集終了"
    end
  end

  describe "現在の参加者との二重表示" do
    let(:joined_experienced) { FactoryBot.create(:customer, name: "参加も経験も花子") }

    before do
      CommunityCustomer.find_or_create_by!(customer: joined_experienced, community: community)
      # 過去イベントで経験あり かつ 今回イベントの同じパートへ参加中
      FactoryBot.create(:join_part_customer, join_part: past_part, customer: joined_experienced)
      FactoryBot.create(:join_part_customer, join_part: current_part, customer: joined_experienced)
    end

    it "権限者: 参加者表示のみで、依頼候補には出さない" do
      sign_in owner
      show_event

      expect(doc.css(".member-display").text).to include "参加も経験も花子"
      expect(doc.css(".entry-invitation-candidate").text).not_to include "参加も経験も花子"
    end

    it "一般ユーザー: 参加者表示のみで、経験者欄には出さない" do
      sign_in general_member
      show_event

      expect(doc.css(".member-display").text).to include "参加も経験も花子"
      expect(doc.css(".experienced-customers").text).not_to include "参加も経験も花子"
    end
  end

  it "退会ユーザーは候補に表示されない" do
    withdrawn = FactoryBot.create(:customer, name: "退会花子", is_deleted: true)
    CommunityCustomer.find_or_create_by!(customer: withdrawn, community: community)
    FactoryBot.create(:join_part_customer, join_part: past_part, customer: withdrawn)

    sign_in owner
    show_event

    expect(response.body).not_to include "退会花子"
  end

  it "レガシーなパート表記(「ボーカル」)でも正規化してVocal列に候補表示される" do
    legacy_past_song = FactoryBot.create(:song, event: past_event, song_name: "旧曲", artist_name: "旧アーティスト")
    legacy_current_song = FactoryBot.create(:song, event: current_event, song_name: "旧曲", artist_name: "旧アーティスト")
    legacy_past_part = FactoryBot.create(:join_part, song: legacy_past_song, join_part_name: "ボーカル")
    FactoryBot.create(:join_part, song: legacy_current_song, join_part_name: "ボーカル")
    FactoryBot.create(:join_part_customer, join_part: legacy_past_part, customer: experienced_customer)

    sign_in owner
    show_event

    token = "#{legacy_current_song.id}:#{JoinPart.find_by(song: legacy_current_song, join_part_name: 'ボーカル').id}:#{experienced_customer.id}"
    expect(doc.css("input[name='targets[]']").map { |cb| cb["value"] }).to include token
  end

  it "パネルは楽曲表フォームの後・イベント補足より前に描画される" do
    sign_in owner
    show_event

    songs_pos = response.body.index("event-songs-join-form")
    form_pos = response.body.index("entry-invitation-form")
    supplement_pos = response.body.index("イベント補足")

    expect(songs_pos).to be < form_pos
    expect(form_pos).to be < supplement_pos
  end

  it "送信フォームは 1 箇所だけに描画される" do
    sign_in owner
    show_event
    expect(response.body.scan('id="entry-invitation-form"').size).to eq 1
  end

  describe "一般ユーザー" do
    before do
      sign_in general_member
      show_event
    end

    it "checkbox・targets[]・送信ボタン・状態バッジ・見出し・一括送信フォームを表示しない" do
      expect(response.body).not_to include "js-entry-invitation-checkbox"
      expect(response.body).not_to include "js-entry-invitation-submit"
      expect(response.body).not_to include "targets[]"
      expect(response.body).not_to include "entry-invitation-form"
      expect(response.body).not_to include "演奏経験者へエントリーをお願いする"
    end

    it "「演奏したことのある人」の氏名とプロフィールリンクは表示する" do
      expect(response.body).to include "演奏経験のある人"
      link = doc.at_css(".experienced-customers__name[href='#{public_customer_path(experienced_customer)}']")
      expect(link).to be_present
      expect(link.text).to include "経験太郎"
    end

    it "一般ユーザーにはアバター・緑丸を追加しない(経験者欄)" do
      expect(doc.at_css(".experienced-customers .avatar-with-badge")).to be_nil
    end
  end

  describe "送信ボタンの有効・無効(選択できる候補の有無)" do
    it "1人でも invitable がいれば送信ボタンは有効(disabled属性なし)" do
      sign_in owner
      show_event

      button = doc.at_css(".js-entry-invitation-submit")
      expect(button).to be_present
      expect(button["disabled"]).to be_nil
      expect(response.body).not_to include "現在、依頼できる演奏経験者はいません"
    end

    it "1人でも invited_resendable がいれば送信ボタンは有効" do
      FactoryBot.create(:entry_invitation,
        event: current_event, song: current_song, join_part: current_part,
        customer: experienced_customer, requested_by_customer: owner, sent_at: 2.days.ago)
      sign_in owner
      show_event

      expect(doc.at_css(".js-entry-invitation-submit")["disabled"]).to be_nil
    end

    it "経験者はいるが全員が募集終了なら送信ボタンは disabled + 補足文を表示" do
      joiner = FactoryBot.create(:customer, name: "参加済次郎")
      CommunityCustomer.find_or_create_by!(customer: joiner, community: community)
      FactoryBot.create(:join_part_customer, join_part: current_part, customer: joiner)
      sign_in owner
      show_event

      expect(doc.at_css(".js-entry-invitation-submit")["disabled"]).to eq "disabled"
      expect(response.body).to include "現在、依頼できる演奏経験者はいません"
      # 経験者名と状態バッジ・フォーム本体は引き続き表示する
      expect(doc.css(".entry-invitation-candidate").text).to include "経験太郎"
      expect(doc.css("#entry-invitation-form").size).to eq 1
    end

    it "経験者はいるが全員が24時間以内に依頼済みなら送信ボタンは disabled + 補足文を表示" do
      FactoryBot.create(:entry_invitation,
        event: current_event, song: current_song, join_part: current_part,
        customer: experienced_customer, requested_by_customer: owner, sent_at: 1.hour.ago)
      sign_in owner
      show_event

      expect(doc.at_css(".js-entry-invitation-submit")["disabled"]).to eq "disabled"
      expect(response.body).to include "現在、依頼できる演奏経験者はいません"
    end

    it "一般ユーザーには補足文を表示しない" do
      joiner = FactoryBot.create(:customer, name: "参加済次郎")
      CommunityCustomer.find_or_create_by!(customer: joiner, community: community)
      FactoryBot.create(:join_part_customer, join_part: current_part, customer: joiner)
      sign_in general_member
      show_event

      expect(response.body).not_to include "現在、依頼できる演奏経験者はいません"
    end
  end

  describe "スマホ向け操作案内" do
    it "権限者の画面DOMに d-md-none 付きの案内文が存在する" do
      sign_in owner
      show_event

      hint = doc.at_css(".entry-invitation-form__mobile-hint")
      expect(hint).to be_present
      expect(hint["class"]).to include "d-md-none"
      expect(hint.text).to include "楽曲表を横にスクロール"
    end

    it "一般ユーザーには案内文を表示しない" do
      sign_in general_member
      show_event

      expect(response.body).not_to include "entry-invitation-form__mobile-hint"
      expect(response.body).not_to include "楽曲表を横にスクロールして、依頼したいメンバーを選択してください"
    end
  end

  it "管理者・コミュニティ管理権限者には送信フォームが表示される" do
    [admin, manager].each do |privileged|
      sign_in privileged
      show_event
      expect(doc.css("#entry-invitation-form").size).to eq 1
    end
  end

  it "未ログインではイベント詳細自体が表示されない" do
    show_event
    expect(response).to have_http_status(:found)
  end

  it "演奏経験者がいない場合は送信フォームを表示しない" do
    JoinPartCustomer.delete_all
    sign_in owner
    show_event
    expect(response.body).not_to include "entry-invitation-form"
  end

  it "終了済みイベントでは送信フォーム・checkbox・送信ボタンを表示しない(経験者名は維持)" do
    sign_in owner
    travel_to(5.days.from_now) do
      show_event
      expect(response.body).not_to include "entry-invitation-form"
      expect(response.body).not_to include "js-entry-invitation-checkbox"
      expect(response.body).not_to include "js-entry-invitation-submit"
    end
  end

  it "曲・パートが増えても entry_invitations のクエリ数が一定(N+1しない)" do
    sign_in owner

    query_count = lambda do
      count = 0
      counter = ->(*, payload) { count += 1 if payload[:sql] =~ /\bentry_invitations\b/i && payload[:name] != "SCHEMA" }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { show_event }
      count
    end

    baseline = query_count.call

    2.times do |i|
      s = FactoryBot.create(:song, event: current_event, song_name: "共通曲", artist_name: "共通アーティスト")
      FactoryBot.create(:join_part, song: s, join_part_name: "Vocal")
      ps = FactoryBot.create(:song, event: past_event, song_name: "共通曲", artist_name: "共通アーティスト")
      pp = FactoryBot.create(:join_part, song: ps, join_part_name: "Vocal")
      FactoryBot.create(:join_part_customer, join_part: pp, customer: FactoryBot.create(:customer, name: "経験者#{i}"))
    end

    expect(query_count.call).to eq baseline
  end

  it "候補のプロフィール画像取得で Active Storage の N+1 が発生しない" do
    sign_in owner

    as_query_count = lambda do
      count = 0
      counter = ->(*, payload) { count += 1 if payload[:sql] =~ /active_storage/i && payload[:name] != "SCHEMA" }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { show_event }
      count
    end

    baseline = as_query_count.call

    2.times do |i|
      s = FactoryBot.create(:song, event: current_event, song_name: "共通曲", artist_name: "共通アーティスト")
      FactoryBot.create(:join_part, song: s, join_part_name: "Vocal")
      ps = FactoryBot.create(:song, event: past_event, song_name: "共通曲", artist_name: "共通アーティスト")
      pp = FactoryBot.create(:join_part, song: ps, join_part_name: "Vocal")
      FactoryBot.create(:join_part_customer, join_part: pp, customer: FactoryBot.create(:customer, name: "追加経験者#{i}"))
    end

    expect(as_query_count.call).to eq baseline
  end
end
