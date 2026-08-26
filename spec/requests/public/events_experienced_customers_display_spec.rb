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
  # 「演奏経験のある人」は募集中(参加者0人)のパート欄に表示するため、current_songに
  # 空のVocalパート(募集中スロット)を用意しておく。
  let(:current_vocal_part) { FactoryBot.create(:join_part, song: current_song, join_part_name: "Vocal") }

  before do
    CommunityCustomer.find_or_create_by!(customer: viewer, community: community)
    current_vocal_part
    past_song
    sign_in viewer
  end

  it '過去の演奏実績がある場合、経験者として表示されること' do
    FactoryBot.create(:song_performance, customer: experienced_customer, song: past_song, song_master: past_song.song_master, event: past_event, join_part: nil, part_name: "Vocal")

    get public_event_path(current_event)

    expect(response.body).to include("演奏経験のある人")
    expect(response.body).to include("経験太郎")
  end

  it '現在閲覧中のイベント自身のエントリーだけでは経験者として表示されないこと' do
    FactoryBot.create(:join_part_customer, join_part: current_vocal_part, customer: experienced_customer)

    get public_event_path(current_event)

    expect(response.body).not_to include("演奏経験のある人")
  end

  it '退会済みユーザーは経験者として表示されないこと' do
    FactoryBot.create(:song_performance, customer: withdrawn_customer, song: past_song, song_master: past_song.song_master, event: past_event, join_part: nil, part_name: "Vocal")

    get public_event_path(current_event)

    expect(response.body).not_to include("退会花子")
  end

  it '該当データがない場合は経験者欄自体が表示されないこと' do
    get public_event_path(current_event)

    expect(response.body).not_to include("演奏経験のある人")
  end

  it '同じユーザーが複数回演奏していても重複表示しないこと' do
    other_past_event = FactoryBot.create(
      :event, :event_with_songs, community: community,
      event_start_time: 6.days.ago, event_end_time: 5.days.ago, event_entry_deadline: 7.days.ago
    )
    other_song = FactoryBot.create(:song, event: other_past_event, song_name: "共通曲", artist_name: "共通アーティスト", song_master: past_song.song_master)

    FactoryBot.create(:song_performance, customer: experienced_customer, song: past_song, song_master: past_song.song_master, event: past_event, join_part: nil, part_name: "Vocal")
    FactoryBot.create(:song_performance, customer: experienced_customer, song: other_song, song_master: past_song.song_master, event: other_past_event, join_part: nil, part_name: "Vocal")

    get public_event_path(current_event)

    # デスクトップ用テーブルとスマホ用募集ショートカットの2箇所に表示されるが、
    # customerとしては重複なく1人分のみが対象になっていることをそれぞれの一覧で確認する。
    experienced_customer_links = Nokogiri::HTML(response.body).css(".experienced-customers__name[href='#{public_customer_path(experienced_customer)}']")
    experienced_customer_links.each do |link|
      expect(link.parent.css(".experienced-customers__name").size).to eq 1
    end
  end
end
