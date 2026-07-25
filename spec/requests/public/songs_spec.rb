require 'rails_helper'

RSpec.describe "Public::Songs", type: :request do
  let(:customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:community) { FactoryBot.create(:community) }
  let(:event) { FactoryBot.create(:event, :event_with_songs, customer: customer, community: community) }

  before { sign_in customer }

  describe "GET show" do
    it "200 OKで曲詳細を表示すること" do
      song = FactoryBot.create(:song, event: event, song_name: "テスト楽曲")

      get public_event_song_path(event, song)

      expect(response.status).to eq 200
      expect(response.body).to include("テスト楽曲")
    end

    it "アーティスト名が登録されていれば表示すること" do
      song = FactoryBot.create(:song, event: event, artist_name: "テストアーティスト")

      get public_event_song_path(event, song)

      expect(response.body).to include("テストアーティスト")
    end

    it "アーティスト名が未登録でもエラーにならず「未設定」と表示すること" do
      song = FactoryBot.create(:song, event: event, artist_name: nil)

      get public_event_song_path(event, song)

      expect(response.status).to eq 200
      expect(response.body).to include("未設定")
    end
  end
end
