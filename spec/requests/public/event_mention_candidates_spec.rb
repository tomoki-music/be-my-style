require "rails_helper"

RSpec.describe "events#mention_candidates", type: :request do
  let(:customer) { create(:customer, name: "Tomoki") }
  let(:event) { create(:event, :event_with_songs) }
  let(:song) { event.songs.first }
  let(:join_part) { create(:join_part, song: song) }
  let(:other_join_part) { create(:join_part, song: song) }
  let(:participant) { create(:customer, name: "参加太郎") }

  before do
    create(:join_part_customer, join_part: join_part, customer: customer)
    create(:join_part_customer, join_part: other_join_part, customer: participant)
  end

  context "ログイン済みの場合" do
    before { sign_in customer }

    it "200 OKでALL候補+イベント参加者候補をJSONで返すこと" do
      get mention_candidates_public_event_path(event)
      expect(response).to have_http_status(200)

      body = JSON.parse(response.body)
      expect(body.first).to include("id" => "all", "name" => "ALL", "type" => "all")
      expect(body.map { |c| c["id"] }).to include(participant.id)
      expect(body.first.keys).to include("id", "name", "avatar_url", "type")
    end

    it "レスポンスに自分自身の情報を含まないこと" do
      get mention_candidates_public_event_path(event)
      body = JSON.parse(response.body)
      expect(body.map { |c| c["id"] }).not_to include(customer.id)
    end

    it "このイベントに参加していないCustomerを含まないこと" do
      other_event_participant = create(:customer, name: "他イベント参加者")
      other_event = create(:event, :event_with_songs)
      other_join_part_for_other_event = create(:join_part, song: other_event.songs.first)
      create(:join_part_customer, join_part: other_join_part_for_other_event, customer: other_event_participant)

      get mention_candidates_public_event_path(event)
      body = JSON.parse(response.body)
      expect(body.map { |c| c["id"] }).not_to include(other_event_participant.id)
    end

    it "退会済みの参加者を含まないこと" do
      participant.update!(is_deleted: true)
      get mention_candidates_public_event_path(event)
      body = JSON.parse(response.body)
      expect(body.map { |c| c["id"] }).not_to include(participant.id)
    end

    it "qパラメータで絞り込めること(ALLも対象)" do
      get mention_candidates_public_event_path(event), params: { q: "参加" }
      body = JSON.parse(response.body)
      expect(body.map { |c| c["id"] }).to eq [participant.id]

      get mention_candidates_public_event_path(event), params: { q: "AL" }
      body = JSON.parse(response.body)
      expect(body.map { |c| c["id"] }).to eq ["all"]

      get mention_candidates_public_event_path(event), params: { q: "nomatch" }
      body = JSON.parse(response.body)
      expect(body).to eq []
    end

    it "不正なパラメータ(極端に長いq)でも例外にならないこと" do
      get mention_candidates_public_event_path(event), params: { q: "a" * 5000 }
      expect(response).to have_http_status(200)
    end
  end

  context "未ログインの場合" do
    it "302 Foundとなること" do
      get mention_candidates_public_event_path(event)
      expect(response).to have_http_status(302)
    end
  end
end
