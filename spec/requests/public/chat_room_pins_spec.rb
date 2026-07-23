require "rails_helper"

RSpec.describe "チャットルーム内ピン留め一覧(GET /chat_rooms/:id/pins)のテスト", type: :request do
  let(:customer) { create(:customer) }
  let(:other_customer) { create(:customer) }
  let(:chat_room) { create(:chat_room) }

  describe "DMの場合" do
    before do
      create(:chat_room_customer, chat_room: chat_room, customer: customer)
      create(:chat_room_customer, chat_room: chat_room, customer: other_customer)
    end

    context "参加者としてログイン済み" do
      before { sign_in customer }

      it "ピン留めされたメッセージがピン留め日時の新しい順で返ること" do
        older = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "先にピンされた投稿")
        newer = create(:chat_message, customer: customer, chat_room: chat_room, content: "後からピンされた投稿")
        create(:chat_message_pin, chat_message: older, pinned_by_customer: customer, created_at: 2.days.ago)
        create(:chat_message_pin, chat_message: newer, pinned_by_customer: customer, created_at: 1.day.ago)

        get pins_public_chat_room_path(chat_room)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["total_count"]).to eq 2
        expect(json["html"].index("後からピンされた投稿")).to be < json["html"].index("先にピンされた投稿")
      end

      it "ピン留めされていないメッセージは含まれないこと" do
        create(:chat_message, customer: customer, chat_room: chat_room, content: "ピンされていない投稿")
        pinned = create(:chat_message, customer: customer, chat_room: chat_room, content: "ピンされた投稿")
        create(:chat_message_pin, chat_message: pinned, pinned_by_customer: customer)

        get pins_public_chat_room_path(chat_room)

        json = JSON.parse(response.body)
        expect(json["total_count"]).to eq 1
        expect(json["html"]).to include("ピンされた投稿")
        expect(json["html"]).not_to include("ピンされていない投稿")
      end

      it "スレッド返信がピン留めされている場合、スレッド内の返信であることが分かること" do
        root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿")
        reply = create(:chat_message, customer: customer, chat_room: chat_room, content: "重要な返信",
                                       reply_to_chat_message: root)
        create(:chat_message_pin, chat_message: reply, pinned_by_customer: customer)

        get pins_public_chat_room_path(chat_room)

        json = JSON.parse(response.body)
        expect(json["html"]).to include("スレッド内の返信")
        expect(json["html"]).to match(/data-pin-message-id=['"]#{reply.id}['"]/)
        expect(json["html"]).to match(/data-pin-root-id=['"]#{root.id}['"]/)
        expect(json["html"]).to match(/data-pin-is-reply=['"]true['"]/)
      end

      it "他ルームのピン留めが混入しないこと" do
        create(:chat_message_pin,
               chat_message: create(:chat_message, customer: customer, chat_room: chat_room, content: "このルームの投稿"),
               pinned_by_customer: customer)
        other_room = create(:chat_room)
        create(:chat_room_customer, chat_room: other_room, customer: customer)
        create(:chat_message_pin,
               chat_message: create(:chat_message, customer: customer, chat_room: other_room, content: "他ルームの投稿"),
               pinned_by_customer: customer)

        get pins_public_chat_room_path(chat_room)

        json = JSON.parse(response.body)
        expect(json["total_count"]).to eq 1
      end

      it "ピン留めが0件の場合、案内文を表示すること" do
        get pins_public_chat_room_path(chat_room)

        json = JSON.parse(response.body)
        expect(json["total_count"]).to eq 0
        expect(json["html"]).to include("ピン留めされたメッセージはまだありません")
      end
    end

    context "非参加者としてログイン済み" do
      it "取得できず404を返すこと" do
        stranger = create(:customer)
        sign_in stranger

        get pins_public_chat_room_path(chat_room)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "非ログイン" do
      it "302でログイン画面へリダイレクトされること" do
        get pins_public_chat_room_path(chat_room)
        expect(response).to have_http_status(302)
      end
    end
  end

  describe "コミュニティの場合" do
    let(:community) { create(:community, owner_id: 0) }
    let(:member) { create(:customer) }

    before do
      create(:chat_room_customer, chat_room: chat_room, customer: customer, community: community)
      create(:chat_room_customer, chat_room: chat_room, customer: member, community: community)
      CommunityCustomer.find_or_create_by!(customer: customer, community: community)
      CommunityCustomer.find_or_create_by!(customer: member, community: community)
    end

    context "コミュニティメンバーとしてログイン済み" do
      before { sign_in customer }

      it "ピン留め一覧を取得できること" do
        pinned = create(:chat_message, customer: member, chat_room: chat_room, community: community, content: "重要な告知")
        create(:chat_message_pin, chat_message: pinned, pinned_by_customer: customer)

        get pins_public_chat_room_path(chat_room)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["html"]).to include("重要な告知")
      end
    end

    context "コミュニティ非メンバーとしてログイン済み" do
      it "取得できず404を返すこと" do
        non_member = create(:customer)
        sign_in non_member

        get pins_public_chat_room_path(chat_room)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "存在しないchat_room" do
    it "存在しないIDでも同じ404を返すこと" do
      sign_in customer
      get pins_public_chat_room_path(id: 999_999)
      expect(response).to have_http_status(:not_found)
    end
  end
end
