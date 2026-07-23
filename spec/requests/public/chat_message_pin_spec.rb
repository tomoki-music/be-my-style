require "rails_helper"

RSpec.describe "メッセージのピン留め/解除(POST/DELETE /chat_messages/:id/pin)のテスト", type: :request do
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

      it "通常メッセージをピン留めできること" do
        chat_message = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "重要な告知です")

        post pin_public_chat_message_path(chat_message)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["pinned"]).to be true
        expect(json["html"]).to include("ピン留め済み")
        expect(chat_message.reload.pinned?).to be true
        expect(ChatMessagePin.find_by(chat_message_id: chat_message.id).pinned_by_customer_id).to eq customer.id
      end

      it "スレッド返信もピン留めできること" do
        root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿")
        reply = create(:chat_message, customer: customer, chat_room: chat_room, content: "重要な返信",
                                       reply_to_chat_message: root)

        post pin_public_chat_message_path(reply)

        expect(response).to have_http_status(:ok)
        expect(reply.reload.pinned?).to be true
      end

      it "既にピン済みのメッセージへ再度ピンしても冪等に成功し、レコードが増えないこと" do
        chat_message = create(:chat_message, customer: customer, chat_room: chat_room, content: "本文")
        create(:chat_message_pin, chat_message: chat_message, pinned_by_customer: other_customer)

        expect {
          post pin_public_chat_message_path(chat_message)
        }.not_to change(ChatMessagePin, :count)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["pinned"]).to be true
      end

      it "ピンした本人が解除できること" do
        chat_message = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "本文")
        create(:chat_message_pin, chat_message: chat_message, pinned_by_customer: customer)

        delete pin_public_chat_message_path(chat_message)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["pinned"]).to be false
        expect(chat_message.reload.pinned?).to be false
      end

      it "DMではピンした本人以外の参加者も解除できること" do
        chat_message = create(:chat_message, customer: customer, chat_room: chat_room, content: "本文")
        create(:chat_message_pin, chat_message: chat_message, pinned_by_customer: other_customer)

        delete pin_public_chat_message_path(chat_message)

        expect(response).to have_http_status(:ok)
        expect(chat_message.reload.pinned?).to be false
      end

      it "未ピン状態での解除も冪等に成功すること" do
        chat_message = create(:chat_message, customer: customer, chat_room: chat_room, content: "本文")

        delete pin_public_chat_message_path(chat_message)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["pinned"]).to be false
      end

      it "存在しないメッセージIDでは404を返すこと" do
        post pin_public_chat_message_path(id: 999_999)
        expect(response).to have_http_status(:not_found)
      end

      it "参加していない別ルームのメッセージは404となり、そのルームの投稿権限を借用できないこと" do
        other_room = create(:chat_room)
        create(:chat_room_customer, chat_room: other_room, customer: other_customer)
        other_room_message = create(:chat_message, customer: other_customer, chat_room: other_room, content: "他ルームの本文")

        post pin_public_chat_message_path(other_room_message)

        expect(response).to have_http_status(:not_found)
        expect(other_room_message.reload.pinned?).to be false
      end
    end

    context "非参加者としてログイン済み" do
      it "ピン留めできず404を返すこと" do
        chat_message = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "本文")
        stranger = create(:customer)
        sign_in stranger

        post pin_public_chat_message_path(chat_message)
        expect(response).to have_http_status(:not_found)
        expect(chat_message.reload.pinned?).to be false
      end

      it "解除もできず404を返すこと" do
        chat_message = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "本文")
        create(:chat_message_pin, chat_message: chat_message, pinned_by_customer: other_customer)
        stranger = create(:customer)
        sign_in stranger

        delete pin_public_chat_message_path(chat_message)
        expect(response).to have_http_status(:not_found)
        expect(chat_message.reload.pinned?).to be true
      end
    end

    context "非ログイン" do
      it "302でログイン画面へリダイレクトされること" do
        chat_message = create(:chat_message, customer: customer, chat_room: chat_room, content: "本文")
        post pin_public_chat_message_path(chat_message)
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

      it "ピン留めできること" do
        chat_message = create(:chat_message, customer: member, chat_room: chat_room, community: community, content: "重要な告知")

        post pin_public_chat_message_path(chat_message)

        expect(response).to have_http_status(:ok)
        expect(chat_message.reload.pinned?).to be true
      end

      it "自分がピンしていない場合、解除しようとすると403になること" do
        chat_message = create(:chat_message, customer: member, chat_room: chat_room, community: community, content: "本文")
        create(:chat_message_pin, chat_message: chat_message, pinned_by_customer: member)

        delete pin_public_chat_message_path(chat_message)

        expect(response).to have_http_status(:forbidden)
        expect(chat_message.reload.pinned?).to be true
      end
    end

    context "コミュニティオーナーとしてログイン済み" do
      it "他人がピンしたメッセージでも解除できること" do
        owner = create(:customer)
        owned_community = create(:community, owner_id: owner.id)
        owned_chat_room = create(:chat_room)
        create(:chat_room_customer, chat_room: owned_chat_room, customer: owner, community: owned_community)
        create(:chat_room_customer, chat_room: owned_chat_room, customer: member, community: owned_community)
        CommunityCustomer.find_or_create_by!(customer: owner, community: owned_community)
        CommunityCustomer.find_or_create_by!(customer: member, community: owned_community)

        chat_message = create(:chat_message, customer: member, chat_room: owned_chat_room, community: owned_community, content: "本文")
        create(:chat_message_pin, chat_message: chat_message, pinned_by_customer: member)
        sign_in owner

        delete pin_public_chat_message_path(chat_message)

        expect(response).to have_http_status(:ok)
        expect(chat_message.reload.pinned?).to be false
      end
    end

    context "サイト管理者としてログイン済み" do
      it "他人がピンしたメッセージでも解除できること" do
        admin = create(:customer, is_owner: :admin)
        create(:chat_room_customer, chat_room: chat_room, customer: admin, community: community)
        CommunityCustomer.find_or_create_by!(customer: admin, community: community)

        chat_message = create(:chat_message, customer: member, chat_room: chat_room, community: community, content: "本文")
        create(:chat_message_pin, chat_message: chat_message, pinned_by_customer: member)
        sign_in admin

        delete pin_public_chat_message_path(chat_message)

        expect(response).to have_http_status(:ok)
        expect(chat_message.reload.pinned?).to be false
      end
    end

    context "コミュニティ非メンバーとしてログイン済み" do
      it "ピン留めできず404を返すこと" do
        chat_message = create(:chat_message, customer: member, chat_room: chat_room, community: community, content: "本文")
        non_member = create(:customer)
        sign_in non_member

        post pin_public_chat_message_path(chat_message)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
