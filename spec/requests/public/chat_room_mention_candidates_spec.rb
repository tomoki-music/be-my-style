require "rails_helper"

RSpec.describe "chat_rooms#mention_candidates / community_mention_candidates", type: :request do
  let(:customer) { create(:customer, name: "Tomoki") }
  let(:other_customer) { create(:customer, name: "Yuki") }
  let(:chat_room) { create(:chat_room) }

  describe "GET mention_candidates(DM)" do
    before do
      create(:chat_room_customer, chat_room: chat_room, customer: customer)
      create(:chat_room_customer, chat_room: chat_room, customer: other_customer)
    end

    context "ログイン済みでこのチャットルームの参加者の場合" do
      before { sign_in customer }

      it "200 OKで候補一覧をJSONで返すこと" do
        get mention_candidates_public_chat_room_path(chat_room)
        expect(response).to have_http_status(200)
        body = JSON.parse(response.body)
        expect(body.map { |c| c["id"] }).to eq [other_customer.id]
        expect(body.first.keys).to contain_exactly("id", "name", "avatar_url")
      end

      it "レスポンスに自分自身の情報を含まないこと" do
        get mention_candidates_public_chat_room_path(chat_room)
        body = JSON.parse(response.body)
        expect(body.map { |c| c["id"] }).not_to include(customer.id)
      end

      it "検索文字列が自分の名前と一致しても自分自身は返さないこと" do
        get mention_candidates_public_chat_room_path(chat_room), params: { q: customer.name }
        body = JSON.parse(response.body)
        expect(body.map { |c| c["id"] }).not_to include(customer.id)
      end

      it "qパラメータで絞り込めること" do
        get mention_candidates_public_chat_room_path(chat_room), params: { q: "yu" }
        expect(JSON.parse(response.body).size).to eq 1

        get mention_candidates_public_chat_room_path(chat_room), params: { q: "nomatch" }
        expect(JSON.parse(response.body)).to eq []
      end

      it "自分と同名の別ユーザーがいる場合、その別ユーザーは候補に残ること" do
        namesake = create(:customer, name: "Tomoki")
        create(:chat_room_customer, chat_room: chat_room, customer: namesake)

        get mention_candidates_public_chat_room_path(chat_room), params: { q: "Tomoki" }
        body = JSON.parse(response.body)
        expect(body.map { |c| c["id"] }).to eq [namesake.id]
        expect(body.map { |c| c["id"] }).not_to include(customer.id)
      end

      it "不正なパラメータ(極端に長いq)でも例外にならないこと" do
        get mention_candidates_public_chat_room_path(chat_room), params: { q: "a" * 5000 }
        expect(response).to have_http_status(200)
      end
    end

    context "このチャットルームの参加者でない場合" do
      it "候補を返さないこと" do
        stranger = create(:customer)
        sign_in stranger
        get mention_candidates_public_chat_room_path(chat_room)
        expect(response).to have_http_status(403)
      end
    end

    context "未ログインの場合" do
      it "302 Foundとなること" do
        get mention_candidates_public_chat_room_path(chat_room)
        expect(response).to have_http_status(302)
      end
    end
  end

  describe "GET community_mention_candidates(コミュニティ)" do
    let(:community) { create(:community) }
    let(:member) { create(:customer, name: "メンバー太郎") }

    before do
      CommunityCustomer.find_or_create_by!(customer: customer, community: community)
      CommunityCustomer.find_or_create_by!(customer: member, community: community)
    end

    context "ログイン済みでコミュニティメンバーの場合" do
      before { sign_in customer }

      it "200 OKで候補一覧をJSONで返すこと" do
        get community_mention_candidates_public_chat_rooms_path(community_id: community.id)
        expect(response).to have_http_status(200)
        body = JSON.parse(response.body)
        expect(body.map { |c| c["id"] }).to eq [member.id]
      end

      it "最大件数(MAX_RESULTS)を超えないこと" do
        (Chat::MentionCandidates::MAX_RESULTS + 3).times do |i|
          extra = create(:customer, name: "追加メンバー#{i}")
          CommunityCustomer.find_or_create_by!(customer: extra, community: community)
        end

        get community_mention_candidates_public_chat_rooms_path(community_id: community.id)
        expect(JSON.parse(response.body).size).to eq Chat::MentionCandidates::MAX_RESULTS
      end

      it "自分と同名の別ユーザーがいる場合、その別ユーザーは候補に残ること" do
        namesake = create(:customer, name: "Tomoki")
        CommunityCustomer.find_or_create_by!(customer: namesake, community: community)

        get community_mention_candidates_public_chat_rooms_path(community_id: community.id), params: { q: "Tomoki" }
        body = JSON.parse(response.body)
        expect(body.map { |c| c["id"] }).to eq [namesake.id]
        expect(body.map { |c| c["id"] }).not_to include(customer.id)
      end
    end

    context "コミュニティメンバーでない場合" do
      it "候補を返さないこと" do
        non_member = create(:customer)
        sign_in non_member
        get community_mention_candidates_public_chat_rooms_path(community_id: community.id)
        expect(response).to have_http_status(403)
      end
    end

    context "未ログインの場合" do
      it "302 Foundとなること" do
        get community_mention_candidates_public_chat_rooms_path(community_id: community.id)
        expect(response).to have_http_status(302)
      end
    end
  end
end
