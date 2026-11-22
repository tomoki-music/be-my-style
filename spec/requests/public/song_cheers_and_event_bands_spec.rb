require "rails_helper"

RSpec.describe "楽曲の応援📣とバンド出演枠", type: :request do
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
  let(:song) { FactoryBot.create(:song, event: event, song_name: "セッション曲") }
  let!(:vocal_part) { FactoryBot.create(:join_part, song: song, join_part_name: "Vocal") }
  let(:band_song) { FactoryBot.create(:song, event: event, song_name: "バンド曲A") }
  let!(:band_song_part) { FactoryBot.create(:join_part, song: band_song, join_part_name: "Guitar") }
  let(:band_song2) { FactoryBot.create(:song, event: event, song_name: "バンド曲B") }

  before do
    community.update!(owner_id: owner.id)
    CommunityOwner.find_or_create_by!(customer: owner, community: community)
    [owner, member, drummer].each { |c| CommunityCustomer.find_or_create_by!(customer: c, community: community) }
  end

  def doc
    Nokogiri::HTML(response.body)
  end

  def song_row(name)
    doc.css(".event-songs-table tbody tr").detect { |tr| tr.text.include?(name) }
  end

  def band_params(name: "ザ・テスト", songs: [band_song, band_song2], members: nil)
    {
      event_band: {
        name: name,
        song_ids: [""] + songs.map { |s| s.id.to_s },
        members: members || {
          "Vocal" => { customer_id: "", display_name: "ゲストボーカル" },
          "Drums" => { customer_id: drummer.id.to_s, display_name: "" },
          "Bass" => { customer_id: "", display_name: "" }
        }
      }
    }
  end

  describe "応援する📣" do
    before { sign_in member }

    it "登録・二重登録防止・取消ができ、取消しても演奏エントリーは残る" do
      FactoryBot.create(:join_part_customer, join_part: vocal_part, customer: member)

      post public_event_song_cheer_path(event, song)
      post public_event_song_cheer_path(event, song)
      expect(SongCheer.where(song: song, customer: member).count).to eq 1

      expect { delete public_event_song_cheer_path(event, song) }.to change(SongCheer, :count).by(-1)
      expect(JoinPartCustomer.where(join_part: vocal_part, customer: member)).to exist
    end

    it "DBでも同じ人・同じ曲の応援は1件まで" do
      SongCheer.create!(song: song, customer: member)
      duplicate = SongCheer.new(song: song, customer: member)
      expect(duplicate).not_to be_valid
      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "応援は成立判定・参加人数に影響しない" do
      get public_event_path(event)
      complete_count_before = doc.text[/\d+曲 成立!!/]
      joined_count_before = doc.text[/\d+人/]

      post public_event_song_cheer_path(event, song)
      expect(song.reload).to be_recruiting

      get public_event_path(event)
      row = song_row("セッション曲")
      expect(row.text).to include("募集中!!")
      expect(row.at_css(".song-cheer__count").text).to include("1")
      expect(row.at_css(".song-cheer__button").text).to include("応援を取り消す")
      expect(doc.text[/\d+曲 成立!!/]).to eq complete_count_before
      expect(doc.text[/\d+人/]).to eq joined_count_before
      expect(doc.css("th").map(&:text)).to include("応援する📣")
    end

    it "コミュニティ外の会員は応援できない" do
      sign_in outsider
      expect { post public_event_song_cheer_path(event, song) }.not_to change(SongCheer, :count)
    end

    it "終了したイベントの曲は応援できない" do
      event.update_columns(event_start_time: 2.days.ago, event_end_time: 1.day.ago)
      expect { post public_event_song_cheer_path(event, song) }.not_to change(SongCheer, :count)
    end
  end

  describe "バンド出演枠" do
    it "編集権限者がバンド名・担当者・出演曲を登録でき、楽曲一覧に固定メンバーが表示されて一般募集されない" do
      sign_in owner
      post public_event_bands_path(event), params: band_params
      band = event.event_bands.last
      expect(band.name).to eq "ザ・テスト"
      expect(band.ordered_members.map { |m| [m.part_name, m.label] }).to eq [["Vocal", "ゲストボーカル"], ["Drums", "ドラム会員"]]
      expect([band_song.reload, band_song2.reload].map(&:event_band_id)).to all(eq band.id)

      sign_in member
      get public_event_path(event)
      row = song_row("バンド曲A")
      expect(row.text).to include("バンド出演🎸", "ザ・テスト", "ゲストボーカル", "ドラム会員")
      expect(row.css(".js-join-part-checkbox")).to be_empty
      expect(row.css(".js-entry-invitation-checkbox")).to be_empty
      expect(row.at_css(".song-cheer__button").text).to include("応援する📣")
      expect(song_row("セッション曲").css(".js-join-part-checkbox")).not_to be_empty

      # 画面を経由しない直接リクエストでも、バンド出演曲には演奏エントリーできない
      expect {
        post public_event_join_path(event), params: { join_part_ids: { "0" => band_song_part.id.to_s } }
      }.not_to change(JoinPartCustomer, :count)

      # 応援は使える
      expect { post public_event_song_cheer_path(event, band_song) }.to change(SongCheer, :count).by(1)
    end

    it "演奏エントリーがある曲は切り替えず、理由を表示して申込みを残す" do
      FactoryBot.create(:join_part_customer, join_part: band_song_part, customer: member)
      sign_in owner
      post public_event_bands_path(event), params: band_params

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("「バンド曲A」には演奏エントリーがあるため、バンド出演曲に切り替えられません")
      expect(event.event_bands).to be_empty
      expect(band_song.reload.event_band_id).to be_nil
      expect(JoinPartCustomer.where(join_part: band_song_part, customer: member)).to exist
    end

    it "開催コミュニティ外の会員は担当者に選べない" do
      sign_in owner
      post public_event_bands_path(event),
           params: band_params(members: { "Vocal" => { customer_id: outsider.id.to_s, display_name: "" } })
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Vocalの担当者は開催コミュニティの有効なメンバーから選んでください")
    end

    it "権限のない会員は固定枠を登録・変更・削除できない" do
      band = event.event_bands.create!(name: "既存バンド")
      band.update!(selected_song_ids: [band_song.id])
      sign_in member

      get public_event_bands_path(event)
      expect(response).to redirect_to(public_event_path(event))
      expect { post public_event_bands_path(event), params: band_params }.not_to change(EventBand, :count)
      patch public_event_band_path(event, band), params: band_params(name: "乗っ取り", songs: [])
      expect(band.reload.name).to eq "既存バンド"
      expect(band_song.reload.event_band_id).to eq band.id
      expect { delete public_event_band_path(event, band) }.not_to change(EventBand, :count)
    end

    it "編集で担当者を空欄にでき、バンドを削除すると出演曲は通常のセッション曲に戻る" do
      sign_in owner
      post public_event_bands_path(event), params: band_params
      band = event.event_bands.last

      patch public_event_band_path(event, band), params: band_params(
        songs: [band_song],
        members: { "Vocal" => { customer_id: "", display_name: "" }, "Drums" => { customer_id: drummer.id.to_s } }
      )
      expect(band.reload.ordered_members.map(&:part_name)).to eq ["Drums"]
      expect(band_song2.reload.event_band_id).to be_nil

      delete public_event_band_path(event, band)
      expect(band_song.reload.event_band_id).to be_nil
      expect(Song.exists?(band_song.id)).to be true
    end

    it "一覧・追加・編集画面と、バンド出演曲の曲詳細が表示できる" do
      FactoryBot.create(:join_part_customer, join_part: vocal_part, customer: member)
      band = event.event_bands.create!(name: "表示確認バンド", selected_song_ids: [band_song.id])
      band.members.create!(part_name: "Drums", customer: drummer)
      sign_in owner

      get public_event_bands_path(event)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("表示確認バンド", "ドラム会員", "バンド曲A")

      get new_public_event_band_path(event)
      expect(response).to have_http_status(:ok)
      session_checkbox = doc.at_css("#event_band_song_ids_#{song.id}")
      expect(session_checkbox["disabled"]).to be_present
      expect(response.body).to include("演奏エントリーがあるため切り替えできません", "別のバンドの出演曲です")

      get edit_public_event_band_path(event, band)
      expect(response).to have_http_status(:ok)
      expect(doc.at_css("#event_band_song_ids_#{band_song.id}")["checked"]).to be_present
      expect(doc.at_css("#event_band_members_drums_customer_id option[selected]").text).to eq "ドラム会員"

      get public_event_song_path(event, band_song)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("バンド出演🎸", "表示確認バンド", "ドラム会員", "応援する📣")
      expect(doc.css(".js-join-part-checkbox")).to be_empty
    end

    it "バンド出演曲はエントリー依頼の対象から外れる" do
      experienced = FactoryBot.create(:customer, name: "経験者")
      CommunityCustomer.find_or_create_by!(customer: experienced, community: community)
      past_event = FactoryBot.create(
        :event, :event_with_songs, community: community, customer: owner,
        event_start_time: 3.days.ago, event_end_time: 2.days.ago, event_entry_deadline: 4.days.ago
      )
      past_song = FactoryBot.create(:song, event: past_event, song_name: "バンド曲A")
      past_part = FactoryBot.create(:join_part, song: past_song, join_part_name: "Guitar")
      FactoryBot.create(:join_part_customer, join_part: past_part, customer: experienced)
      target = ["#{band_song.id}:#{band_song_part.id}:#{experienced.id}"]

      expect(EntryInvitations::TargetResolver.call(event: event, raw_targets: target).size).to eq 1

      band = event.event_bands.create!(name: "依頼対象外バンド")
      band.update!(selected_song_ids: [band_song.id])
      expect(EntryInvitations::TargetResolver.call(event: event.reload, raw_targets: target)).to be_empty
    end
  end
end
