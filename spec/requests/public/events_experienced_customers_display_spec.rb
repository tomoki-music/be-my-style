require 'rails_helper'

RSpec.describe "Public::Events#show 楽曲パート募集欄の経験者表示", type: :request do
  let(:viewer) { FactoryBot.create(:customer) }
  let(:experienced_customer) { FactoryBot.create(:customer, name: "経験太郎") }
  let(:withdrawn_customer) { FactoryBot.create(:customer, name: "退会花子", is_deleted: true) }
  let(:community) { FactoryBot.create(:community) }

  let(:past_event) do
    FactoryBot.create(
      :event,
      :event_with_songs,
      community: community,
      event_start_time: 3.days.ago,
      event_end_time: 2.days.ago,
      event_entry_deadline: 4.days.ago
    )
  end
  let(:upcoming_event) do
    FactoryBot.create(
      :event,
      :event_with_songs,
      community: community,
      event_start_time: 2.days.from_now,
      event_end_time: 3.days.from_now,
      event_entry_deadline: 1.day.from_now
    )
  end
  let(:current_event) do
    FactoryBot.create(
      :event,
      :event_with_songs,
      community: community,
      event_start_time: 2.days.from_now,
      event_end_time: 3.days.from_now,
      event_entry_deadline: 1.day.from_now
    )
  end

  let(:past_song) { FactoryBot.create(:song, event: past_event, song_name: "共通曲", artist_name: "共通アーティスト") }
  let(:current_song) { FactoryBot.create(:song, event: current_event, song_name: "共通曲", artist_name: "共通アーティスト") }
  let(:past_vocal_part) { FactoryBot.create(:join_part, song: past_song, join_part_name: "Vocal") }
  # 「演奏経験のある人」は募集中(参加者0人)のパート欄に表示するため、current_songに
  # 空のVocalパート(募集中スロット)を用意しておく。
  let(:current_vocal_part) { FactoryBot.create(:join_part, song: current_song, join_part_name: "Vocal") }

  before do
    # このファイルは「一般ユーザー向けの経験者氏名表示」を検証する。
    # community factory の owner_id 既定値(1)が viewer.id と偶然一致すると
    # viewer が主催者扱いになり、パート欄が主催者向けの依頼候補UIへ切り替わってしまうため、
    # 明示的に別の主催者を立てて viewer を非権限者に固定する。
    community.update!(owner_id: FactoryBot.create(:customer).id)
    CommunityCustomer.find_or_create_by!(customer: viewer, community: community)
    current_vocal_part
    past_vocal_part
    sign_in viewer
  end

  it '終了済みイベントのエントリーが、確定操作なしで経験者として表示されること' do
    FactoryBot.create(:join_part_customer, join_part: past_vocal_part, customer: experienced_customer)

    get public_event_path(current_event)

    expect(response.body).to include("演奏経験のある人")
    expect(response.body).to include("経験太郎")
  end

  it '開催前イベントのエントリーは経験者として表示されないこと' do
    upcoming_song = FactoryBot.create(:song, event: upcoming_event, song_name: "共通曲", artist_name: "共通アーティスト")
    upcoming_vocal_part = FactoryBot.create(:join_part, song: upcoming_song, join_part_name: "Vocal")
    FactoryBot.create(:join_part_customer, join_part: upcoming_vocal_part, customer: experienced_customer)

    get public_event_path(current_event)

    expect(response.body).not_to include("演奏経験のある人")
  end

  it '現在閲覧中のイベント自身のエントリーだけでは経験者として表示されないこと' do
    FactoryBot.create(:join_part_customer, join_part: current_vocal_part, customer: experienced_customer)

    get public_event_path(current_event)

    expect(response.body).not_to include("演奏経験のある人")
  end

  it '退会済みユーザーは経験者として表示されないこと' do
    FactoryBot.create(:join_part_customer, join_part: past_vocal_part, customer: withdrawn_customer)

    get public_event_path(current_event)

    expect(response.body).not_to include("退会花子")
  end

  it '取消済み(削除済み)のエントリーは経験者として表示されないこと' do
    join_part_customer = FactoryBot.create(:join_part_customer, join_part: past_vocal_part, customer: experienced_customer)
    join_part_customer.destroy!

    get public_event_path(current_event)

    expect(response.body).not_to include("演奏経験のある人")
  end

  it '該当データがない場合は経験者欄自体が表示されないこと' do
    get public_event_path(current_event)

    expect(response.body).not_to include("演奏経験のある人")
  end

  it '別Songレコードでも同じSongMasterであれば同一曲として経験者に表示されること' do
    other_past_event = FactoryBot.create(
      :event, :event_with_songs, community: community,
      event_start_time: 6.days.ago, event_end_time: 5.days.ago, event_entry_deadline: 7.days.ago
    )
    other_song = FactoryBot.create(:song, event: other_past_event, song_name: "共通曲", artist_name: "共通アーティスト")
    expect(other_song.song_master_id).to eq(past_song.song_master_id)
    other_vocal_part = FactoryBot.create(:join_part, song: other_song, join_part_name: "Vocal")
    FactoryBot.create(:join_part_customer, join_part: other_vocal_part, customer: experienced_customer)

    get public_event_path(current_event)

    expect(response.body).to include("経験太郎")
  end

  it '同じユーザーが複数回演奏していても重複表示しないこと' do
    other_past_event = FactoryBot.create(
      :event, :event_with_songs, community: community,
      event_start_time: 6.days.ago, event_end_time: 5.days.ago, event_entry_deadline: 7.days.ago
    )
    other_song = FactoryBot.create(:song, event: other_past_event, song_name: "共通曲", artist_name: "共通アーティスト")
    other_vocal_part = FactoryBot.create(:join_part, song: other_song, join_part_name: "Vocal")

    FactoryBot.create(:join_part_customer, join_part: past_vocal_part, customer: experienced_customer)
    FactoryBot.create(:join_part_customer, join_part: other_vocal_part, customer: experienced_customer)

    get public_event_path(current_event)

    # デスクトップ用テーブルとスマホ用募集ショートカットの2箇所に表示されるが、
    # customerとしては重複なく1人分のみが対象になっていることをそれぞれの一覧で確認する。
    experienced_customer_links = Nokogiri::HTML(response.body).css(".experienced-customers__name[href='#{public_customer_path(experienced_customer)}']")
    experienced_customer_links.each do |link|
      expect(link.parent.css(".experienced-customers__name").size).to eq 1
    end
  end

  it '過去イベントと現在イベントが同じ旧パート表記(NAME_OPTIONS外の生の値)を使っていても経験者として表示されること' do
    # 2025年1月のセレクトボックス化以前に作られたイベントは、join_part_nameが自由入力の
    # ままDBに残り得る(JoinPartにinclusion validationは無い)。過去イベントと現在イベントの
    # 双方が同じ旧表記(例: 事業運営の実運用で見られる「ボーカル」)を使っている場合でも、
    # Controller/ViewがQueryと同じ正規化済みキーで参照しなければ経験者として一致しない。
    #
    # past_song/current_songには(before付近の共通セットアップにより)既に現行表記"Vocal"の
    # パートが1件ずつ存在するため、同じ曲に旧表記のパートを足すだけでは
    # 「たまたま別の"Vocal"列経由で一致して見える」誤検知が起こり得る。それを避けるため、
    # このテストだけは専用のSong(旧表記のパートしか持たない)を用意して検証する。
    legacy_past_song = FactoryBot.create(:song, event: past_event, song_name: "旧曲", artist_name: "旧アーティスト")
    legacy_current_song = FactoryBot.create(:song, event: current_event, song_name: "旧曲", artist_name: "旧アーティスト")
    expect(legacy_current_song.song_master_id).to eq(legacy_past_song.song_master_id)

    legacy_past_part = FactoryBot.create(:join_part, song: legacy_past_song, join_part_name: "ボーカル")
    legacy_current_part = FactoryBot.create(:join_part, song: legacy_current_song, join_part_name: "ボーカル")
    FactoryBot.create(:join_part_customer, join_part: legacy_past_part, customer: experienced_customer)
    legacy_current_part # 募集中スロットとして存在させる

    get public_event_path(current_event)

    expect(response.body).to include("演奏経験のある人")
    expect(response.body).to include("経験太郎")
  end

  describe '曲名にアーティスト名を含む表記(「曲名（アーティスト名）」)と、曲名+アーティスト欄の表記が混在する場合' do
    # 実運用データで頻出: 過去イベントは song_name="マリーゴールド（あいみょん）" / artist_name 空、
    # 現在イベントは song_name="マリーゴールド" / artist_name="あいみょん" のように登録形式がずれる。
    # 同じ曲なので、経験者(見出し・氏名・公開プロフィールリンク)が表示されなければならない。
    it '過去=「曲名（アーティスト名）」・現在=「曲名」+アーティスト欄 でも同一曲として経験者に表示されること(PC/スマホ両方)' do
      # 括弧内をアーティスト名として切り出すには「曲名」+「アーティスト欄」入力済みという裏付けが必要。
      # 現在イベント側のsplit形式が裏付けになるため、そちらを先に登録する。
      split_current_song = FactoryBot.create(:song, event: current_event, song_name: "マリーゴールド", artist_name: "あいみょん")
      embedded_past_song = FactoryBot.create(:song, event: past_event, song_name: "マリーゴールド（あいみょん）", artist_name: nil)
      expect(split_current_song.song_master_id).to eq(embedded_past_song.song_master_id)

      past_guitar_part = FactoryBot.create(:join_part, song: embedded_past_song, join_part_name: "Guitar")
      FactoryBot.create(:join_part, song: split_current_song, join_part_name: "Guitar") # 現在イベント側の募集中スロット
      FactoryBot.create(:join_part_customer, join_part: past_guitar_part, customer: experienced_customer)

      get public_event_path(current_event)

      expect(response.body).to include("演奏経験のある人")
      expect(response.body).to include("経験太郎")

      doc = Nokogiri::HTML(response.body)
      # 公開プロフィールへのリンクとして描画されること
      profile_links = doc.css(".experienced-customers__name[href='#{public_customer_path(experienced_customer)}']")
      expect(profile_links).to be_present
      # スマホ用募集ショートカット(.recruiting-parts 内)に描画されること
      mobile_names = doc.css(".recruiting-parts .experienced-customers__name")
      expect(mobile_names.text).to include("経験太郎")
      # PC用パート列(.recruiting-parts の外側)にも描画されること
      pc_names = doc.css(".experienced-customers__name").reject { |node| node.ancestors(".recruiting-parts").any? }
      expect(pc_names.map(&:text).join).to include("経験太郎")
    end

    it '過去=「曲名」+アーティスト欄・現在=「曲名（アーティスト名）」の逆パターンでも経験者に表示されること' do
      split_past_song = FactoryBot.create(:song, event: past_event, song_name: "マリーゴールド", artist_name: "あいみょん")
      embedded_current_song = FactoryBot.create(:song, event: current_event, song_name: "マリーゴールド（あいみょん）", artist_name: nil)
      expect(embedded_current_song.song_master_id).to eq(split_past_song.song_master_id)

      past_vocal = FactoryBot.create(:join_part, song: split_past_song, join_part_name: "Vocal")
      FactoryBot.create(:join_part, song: embedded_current_song, join_part_name: "Vocal")
      FactoryBot.create(:join_part_customer, join_part: past_vocal, customer: experienced_customer)

      get public_event_path(current_event)

      expect(response.body).to include("演奏経験のある人")
      expect(response.body).to include("経験太郎")
    end
  end

  it '「演奏実績を確定」ボタンが表示されないこと(動的表示のため確定操作が不要、主催者が閲覧しても表示されない)' do
    owner_past_event = FactoryBot.create(
      :event, :event_with_songs, community: community, customer: viewer,
      event_start_time: 3.days.ago, event_end_time: 2.days.ago, event_entry_deadline: 4.days.ago
    )

    get public_event_path(owner_past_event)

    expect(response.body).not_to include("演奏実績を確定する")
    expect(response.body).not_to include("sync_performances")
  end
end
