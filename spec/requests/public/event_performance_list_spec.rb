require "rails_helper"
require "zip"

RSpec.describe "イベント詳細の演奏リスト（Excel）ダウンロード", type: :request do
  let(:community) { FactoryBot.create(:community) }
  let(:owner) { FactoryBot.create(:customer, name: "主催者") }
  let(:community_owner) { FactoryBot.create(:customer, name: "コミュニティオーナー") }
  let(:member) { FactoryBot.create(:customer, name: "一般メンバー") }
  let(:vocal_a) { FactoryBot.create(:customer, name: "ボーカルA") }
  let(:vocal_b) { FactoryBot.create(:customer, name: "=1+1") }
  let(:withdrawn) { FactoryBot.create(:customer, name: "退会者") }
  let(:drummer) { FactoryBot.create(:customer, name: "ドラム会員") }
  let(:event) do
    FactoryBot.create(
      :event, :event_with_songs, community: community, customer: owner, event_name: "冬セッション",
      event_start_time: Time.zone.local(2030, 1, 12, 18, 0), event_end_time: Time.zone.local(2030, 1, 12, 21, 0),
      event_entry_deadline: Time.zone.local(2030, 1, 5, 18, 0)
    )
  end

  before do
    community.update!(owner_id: community_owner.id)
    [owner, member, vocal_a, vocal_b, withdrawn, drummer].each do |customer|
      CommunityCustomer.find_or_create_by!(customer: customer, community: community)
    end
  end

  def add_members(join_part, *customers)
    customers.each { |customer| JoinPartCustomer.create!(join_part: join_part, customer: customer) }
  end

  # 共有文字列を展開した1行=1配列の表と、生のシートXMLを返す。
  def read_xlsx(binary)
    Zip::File.open_buffer(StringIO.new(binary)) do |zip|
      shared = Nokogiri::XML(zip.read("xl/sharedStrings.xml")).remove_namespaces!
                       .css("si").map { |si| si.css("t").map(&:text).join }
      sheet_xml = zip.read("xl/worksheets/sheet1.xml")
      rows = Nokogiri::XML(sheet_xml).remove_namespaces!.css("sheetData row").map do |row|
        row.css("c").map do |cell|
          value = cell.at_css("v")&.text
          cell["t"] == "s" && value ? shared[value.to_i] : value.to_s
        end
      end
      return [rows, sheet_xml]
    end
  end

  describe "ダウンロード" do
    let!(:second_song) do
      FactoryBot.create(:song, event: event, song_name: "後の曲", position: 2, youtube_url: "https://youtu.be/reference")
    end
    let!(:first_song) do
      event.songs.first.tap do |song|
        song.update!(song_name: "先の曲", artist_name: "アーティスト", position: 1, performance_start_time: "18:15")
      end
    end
    let!(:band_song) { FactoryBot.create(:song, event: event, song_name: "バンド曲", position: 3) }

    before do
      add_members(FactoryBot.create(:join_part, song: first_song, join_part_name: "Vocal"), vocal_a, vocal_b)
      FactoryBot.create(:join_part, song: first_song, join_part_name: "Guitar")
      add_members(FactoryBot.create(:join_part, song: first_song, join_part_name: "Bass"), withdrawn)
      add_members(FactoryBot.create(:join_part, song: second_song, join_part_name: "Cho"), vocal_a)
      withdrawn.update_column(:is_deleted, true)

      band = event.event_bands.create!(name: "固定バンド", selected_song_ids: [band_song.id])
      band.members.create!(part_name: "Drums", customer: drummer)
      band.members.create!(part_name: "Vocal", display_name: "ゲストボーカル")
    end

    it "作成者は曲順どおり・複数人改行・募集中/対象外・固定メンバー入りの .xlsx を取得できる" do
      sign_in owner
      get performance_list_public_event_path(event)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq Events::PerformanceListXlsx::MIME_TYPE
      expect(response.headers["Content-Disposition"]).to include("attachment")

      rows, sheet_xml = read_xlsx(response.body)
      expect(rows[0].first).to eq "冬セッション【演奏リスト】"
      expect(rows[1].first).to include("2030年1月12日(土) 18:00〜21:00")
      expect(rows[5]).to eq ["No.", "演奏時間", "演奏曲目", "Vo", "Gt", "Ba", "Dr", "Key", "Cho", "Other", "演奏動画URL"]

      expect(rows[6]).to eq ["1", "18:15", "先の曲 / アーティスト", "ボーカルA\n=1+1", "募集中", "募集中", "—", "—", "—", "—", ""]
      expect(rows[7]).to eq ["2", "", "後の曲", "—", "—", "—", "—", "—", "ボーカルA", "—", ""]
      expect(rows[8]).to eq ["3", "", "バンド曲\n🎸 バンド出演：固定バンド", "ゲストボーカル", "—", "—", "ドラム会員", "—", "—", "—", ""]

      # 参考動画URLは演奏動画URLに転用せず、表示名以外の会員情報や数式も書き出さない。
      expect(response.body.b).not_to include("youtu.be")
      expect(sheet_xml).not_to include("<f>")
      expect(sheet_xml).to include('state="frozen"', 'orientation="landscape"', 'fitToWidth="1"')
    end

    it "退会者だけのパートは、詳細画面と同じく「募集中」で退会者名を出さない" do
      sign_in owner
      get public_event_path(event)

      doc = Nokogiri::HTML(response.body)
      row = doc.css(".event-songs-table tbody tr").detect { |tr| tr.text.include?("先の曲") }
      bass_cell = row.css("td")[2 + JoinPart::NAME_OPTIONS.index("Bass")]
      expect(bass_cell.text).to include("募集中")
      expect(bass_cell.text).not_to include("退会者")
    end
  end

  describe "権限" do
    let(:admin) { FactoryBot.create(:customer, name: "システム管理者", is_owner: :admin) }
    let(:co_admin) { FactoryBot.create(:customer, name: "管理権限者") }
    let(:other_owner) { FactoryBot.create(:customer, name: "別コミュニティのオーナー") }

    before do
      CommunityOwner.create!(customer: co_admin, community: community)
      FactoryBot.create(:community, owner_id: other_owner.id)
      CommunityCustomer.find_or_create_by!(customer: other_owner, community: community)
    end

    def expect_allowed(customer)
      sign_in customer
      get public_event_path(event)
      expect(response.body).to include("演奏リスト（Excel）", performance_list_public_event_path(event))

      get performance_list_public_event_path(event)
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq Events::PerformanceListXlsx::MIME_TYPE
      sign_out customer
    end

    def expect_denied(customer)
      sign_in customer
      get public_event_path(event)
      expect(response.body).not_to include("演奏リスト（Excel）")

      get performance_list_public_event_path(event)
      expect(response).to redirect_to(public_event_path(event))
      expect(response.media_type).not_to eq Events::PerformanceListXlsx::MIME_TYPE
      sign_out customer
    end

    it "作成者・システム管理者・主催コミュニティのオーナー/管理権限者はボタン表示と取得ができる" do
      [owner, admin, community_owner, co_admin].each { |customer| expect_allowed(customer) }
    end

    it "一般メンバーと、別コミュニティのオーナーはボタンが無く、取得も拒否される" do
      [member, other_owner].each { |customer| expect_denied(customer) }
    end

    it "未ログインはログイン画面へ送る" do
      get performance_list_public_event_path(event)
      expect(response).to have_http_status(:redirect)
      expect(response.location).not_to include("performance_list")
    end
  end
end
