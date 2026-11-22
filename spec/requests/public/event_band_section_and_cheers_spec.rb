require "rails_helper"

RSpec.describe "イベント詳細のバンド出演枠とバンドへの応援📣", type: :request do
  let(:community) { FactoryBot.create(:community) }
  let(:owner) { FactoryBot.create(:customer, name: "主催者") }
  let(:member) { FactoryBot.create(:customer, name: "一般メンバー") }
  let(:drummer) { FactoryBot.create(:customer, name: "ドラム会員") }
  let(:outsider) { FactoryBot.create(:customer, name: "コミュニティ外") }
  let(:event) do
    FactoryBot.create(
      :event, :event_with_songs, community: community, customer: owner,
      event_start_time: 10.days.from_now, event_end_time: 10.days.from_now + 2.hours,
      event_entry_deadline: 5.days.from_now
    )
  end
  let(:band_song) { FactoryBot.create(:song, event: event, song_name: "出演曲A") }
  let!(:band_song_part) { FactoryBot.create(:join_part, song: band_song, join_part_name: "Guitar") }
  let(:band) do
    event.event_bands.create!(name: "曲ありバンド", selected_song_ids: [band_song.id]).tap do |b|
      b.members.create!(part_name: "Drums", customer: drummer)
      b.members.create!(part_name: "Vocal", display_name: "ゲストボーカル")
    end
  end
  let(:band_without_songs) { event.event_bands.create!(name: "曲なしバンド") }

  before do
    community.update!(owner_id: owner.id)
    CommunityOwner.find_or_create_by!(customer: owner, community: community)
    [owner, member, drummer].each { |c| CommunityCustomer.find_or_create_by!(customer: c, community: community) }
  end

  def doc
    Nokogiri::HTML(response.body)
  end

  def band_panel(target)
    doc.at_css("#event-band-#{target.id}")
  end

  describe "楽曲欄上部の「バンド出演🎸」" do
    it "一般メンバーにも、出演曲あり・なしの両方のバンドをメンバー・出演曲付きで表示する" do
      band
      band_without_songs
      sign_in member
      get public_event_path(event)

      section = doc.at_css("#event-bands")
      expect(section.text).to include("バンド出演🎸")

      with_songs = band_panel(band)
      expect(with_songs.text).to include("曲ありバンド", "Vocal", "ゲストボーカル", "Drums", "ドラム会員", "出演曲A")
      expect(with_songs.at_css(".song-cheer__button").text).to include("このバンドを応援する📣")

      without_songs = band_panel(band_without_songs)
      expect(without_songs.text).to include("曲なしバンド", "出演曲は未登録です", "メンバーは未登録です")
    end

    it "楽曲フィルターの対象外の位置に出し、スマホ用に出演曲の行にも固定メンバーを出す" do
      band
      sign_in member
      get public_event_path(event)

      expect(doc.at_css(".event-songs-table #event-bands")).to be_nil
      row = doc.css(".event-songs-table tbody tr").detect { |tr| tr.text.include?("出演曲A") }
      expect(row["class"]).to include("band")
      expect(row.at_css(".song-band-members").text).to include("Drums: ドラム会員", "Vocal: ゲストボーカル")
      expect(row.at_css(".song-band-name a")["href"]).to eq "#event-band-#{band.id}"
    end

    it "バンドが無いイベントでは枠を出さない" do
      sign_in member
      get public_event_path(event)
      expect(doc.at_css("#event-bands")).to be_nil
    end
  end

  describe "このバンドを応援する📣" do
    before { sign_in member }

    it "登録・二重登録防止・取消ができる" do
      post public_event_band_cheer_path(event, band)
      post public_event_band_cheer_path(event, band)
      expect(EventBandCheer.where(event_band: band, customer: member).count).to eq 1

      get public_event_path(event)
      panel = band_panel(band)
      expect(panel.at_css(".song-cheer__count").text).to include("1")
      expect(panel.at_css(".song-cheer__button").text).to include("応援を取り消す")

      expect { delete public_event_band_cheer_path(event, band) }.to change(EventBandCheer, :count).by(-1)
    end

    it "DBでも同じ会員・同じバンドの応援は1件まで" do
      EventBandCheer.create!(event_band: band, customer: member)
      duplicate = EventBandCheer.new(event_band: band, customer: member)
      expect(duplicate).not_to be_valid
      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "曲への応援とは独立していて両方使え、参加人数・成立楽曲数に影響しない" do
      band
      get public_event_path(event)
      joined_before = doc.text[/\d+人/]
      complete_before = doc.text[/\d+曲 成立!!/]

      post public_event_band_cheer_path(event, band)
      post public_event_song_cheer_path(event, band_song)
      expect(EventBandCheer.where(event_band: band, customer: member)).to exist
      expect(SongCheer.where(song: band_song, customer: member)).to exist

      delete public_event_band_cheer_path(event, band)
      expect(SongCheer.where(song: band_song, customer: member)).to exist

      get public_event_path(event)
      expect(doc.text[/\d+人/]).to eq joined_before
      expect(doc.text[/\d+曲 成立!!/]).to eq complete_before
      expect(JoinPartCustomer.where(customer: member)).to be_empty
    end

    it "コミュニティ外の会員と、終了したイベントでは応援できない" do
      sign_in outsider
      expect { post public_event_band_cheer_path(event, band) }.not_to change(EventBandCheer, :count)

      sign_in member
      event.update_columns(event_start_time: 2.days.ago, event_end_time: 1.day.ago)
      expect { post public_event_band_cheer_path(event, band) }.not_to change(EventBandCheer, :count)
    end

    it "別イベントのバンドIDを指定しても応援できない" do
      other_event = FactoryBot.create(:event, :event_with_songs, community: community, customer: owner,
                                      event_start_time: 10.days.from_now, event_end_time: 10.days.from_now + 1.hour)
      # 本番では ActiveRecord::RecordNotFound が 404 になる(テスト環境では例外のまま上がる)。
      expect { post public_event_band_cheer_path(other_event, band) }.to raise_error(ActiveRecord::RecordNotFound)
      expect(EventBandCheer.count).to eq 0
    end
  end
end
