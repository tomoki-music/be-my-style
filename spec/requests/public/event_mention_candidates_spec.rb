require "rails_helper"

RSpec.describe "events#mention_candidates", type: :request do
  let(:community) { create(:community) }
  let(:customer) { create(:customer, name: "Tomoki") }
  let(:event) { create(:event, :event_with_songs, community: community) }
  let(:song) { event.songs.first }
  let(:member) { create(:customer, name: "参加太郎") }

  before do
    CommunityCustomer.find_or_create_by!(customer: customer, community: community)
    CommunityCustomer.find_or_create_by!(customer: member, community: community)
  end

  context "ログイン済みの場合" do
    before { sign_in customer }

    it "200 OKでALL候補+開催元コミュニティのメンバー候補をJSONで返すこと" do
      get mention_candidates_public_event_path(event)
      expect(response).to have_http_status(200)

      body = JSON.parse(response.body)
      expect(body.first).to include("id" => "all", "name" => "ALL", "type" => "all")
      expect(body.map { |c| c["id"] }).to include(member.id)
      expect(body.first.keys).to include("id", "name", "avatar_url", "type")
    end

    it "レスポンスに自分自身の情報を含まないこと" do
      get mention_candidates_public_event_path(event)
      body = JSON.parse(response.body)
      expect(body.map { |c| c["id"] }).not_to include(customer.id)
    end

    it "イベントへ演奏参加登録していないコミュニティメンバーも候補に含まれること" do
      join_part = create(:join_part, song: song)
      expect(join_part.customers).not_to include(member) # memberは一切joinしていない

      get mention_candidates_public_event_path(event)
      body = JSON.parse(response.body)
      expect(body.map { |c| c["id"] }).to include(member.id)
    end

    it "イベントへ演奏参加していても、開催元コミュニティのメンバーでなければ候補に含まれないこと" do
      non_member_participant = create(:customer, name: "参加だけ花子")
      join_part = create(:join_part, song: song)
      create(:join_part_customer, join_part: join_part, customer: non_member_participant)

      get mention_candidates_public_event_path(event)
      body = JSON.parse(response.body)
      expect(body.map { |c| c["id"] }).not_to include(non_member_participant.id)
    end

    it "他コミュニティのメンバーを含まないこと(URLのevent_idを差し替えても他コミュニティ参加者は取得できない)" do
      other_community = create(:community)
      other_member = create(:customer, name: "他コミュニティ太郎")
      CommunityCustomer.find_or_create_by!(customer: other_member, community: other_community)

      get mention_candidates_public_event_path(event)
      body = JSON.parse(response.body)
      expect(body.map { |c| c["id"] }).not_to include(other_member.id)
    end

    it "退会済みのメンバーを含まないこと" do
      member.update!(is_deleted: true)
      get mention_candidates_public_event_path(event)
      body = JSON.parse(response.body)
      expect(body.map { |c| c["id"] }).not_to include(member.id)
    end

    it "候補にメールアドレス等の個人情報を含まないこと" do
      get mention_candidates_public_event_path(event)
      body = JSON.parse(response.body)
      expect(body.first.keys).to contain_exactly("id", "name", "avatar_url", "type")
    end

    it "qパラメータで絞り込めること(ALLも対象)" do
      get mention_candidates_public_event_path(event), params: { q: "参加" }
      body = JSON.parse(response.body)
      expect(body.map { |c| c["id"] }).to eq [member.id]

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
