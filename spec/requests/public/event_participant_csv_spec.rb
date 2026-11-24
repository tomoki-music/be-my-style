require "rails_helper"

RSpec.describe "イベント詳細の参加一覧CSVダウンロード", type: :request do
  let(:community) { FactoryBot.create(:community) }
  let(:creator) { FactoryBot.create(:customer, name: "作成者") }
  let(:community_owner) { FactoryBot.create(:customer, name: "コミュニティオーナー") }
  let(:member) { FactoryBot.create(:customer, name: "一般メンバー") }
  let(:event) do
    FactoryBot.create(
      :event, :event_with_songs, community: community, customer: creator,
      event_start_time: 10.days.from_now, event_end_time: 10.days.from_now + 2.hours,
      event_entry_deadline: 5.days.from_now
    )
  end

  before do
    community.update!(owner_id: community_owner.id)
    [creator, community_owner, member].each do |customer|
      CommunityCustomer.find_or_create_by!(customer: customer, community: community)
    end
  end

  it "イベント作成者はCSVを取得できる" do
    sign_in creator
    get public_event_path(event, format: :csv)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq "text/csv"
    expect(response.body).to include("曲順", event.songs.first.song_name)
  end

  it "作成者以外のログイン済みユーザーはイベント詳細へ戻され、CSVは返らない" do
    [community_owner, member].each do |customer|
      sign_in customer
      get public_event_path(event, format: :csv)

      expect(response).to redirect_to(public_event_path(event))
      expect(response.headers["Content-Disposition"]).to be_nil
      expect(response.body).not_to include("曲順")
      sign_out customer
    end
  end

  it "未ログインでは既存の認証フローどおりログイン画面へ送られ、CSVは返らない" do
    get public_event_path(event, format: :csv)

    expect(response).to redirect_to(new_customer_session_path)
    expect(response.headers["Content-Disposition"]).to be_nil
    expect(response.body).not_to include("曲順")
  end
end
