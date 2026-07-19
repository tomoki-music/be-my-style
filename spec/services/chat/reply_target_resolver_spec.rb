require "rails_helper"

RSpec.describe Chat::ReplyTargetResolver, type: :service do
  describe "DMメッセージへの返信" do
    let(:customer) { create(:customer) }
    let(:other_customer) { create(:customer) }
    let(:chat_room) { create(:chat_room) }

    before do
      create(:chat_room_customer, chat_room: chat_room, customer: customer)
      create(:chat_room_customer, chat_room: chat_room, customer: other_customer)
    end

    it "同じchat_room内のメッセージへの返信を許可すること" do
      original = create(:chat_message, customer: other_customer, chat_room: chat_room)

      resolved = described_class.call(
        reply_to_chat_message_id: original.id,
        chat_room: chat_room,
        community: nil,
        current_customer: customer
      )

      expect(resolved).to eq original
    end

    it "別のchat_room(別DM)のメッセージへの返信を拒否すること" do
      other_chat_room = create(:chat_room)
      create(:chat_room_customer, chat_room: other_chat_room, customer: customer)
      original = create(:chat_message, customer: other_customer, chat_room: other_chat_room)

      resolved = described_class.call(
        reply_to_chat_message_id: original.id,
        chat_room: chat_room,
        community: nil,
        current_customer: customer
      )

      expect(resolved).to be_nil
    end

    it "現在のchat_roomの参加者でないcurrent_customerからの返信は拒否すること" do
      stranger = create(:customer)
      original = create(:chat_message, customer: other_customer, chat_room: chat_room)

      resolved = described_class.call(
        reply_to_chat_message_id: original.id,
        chat_room: chat_room,
        community: nil,
        current_customer: stranger
      )

      expect(resolved).to be_nil
    end

    it "存在しないreply_to_chat_message_idは拒否すること" do
      resolved = described_class.call(
        reply_to_chat_message_id: 999_999,
        chat_room: chat_room,
        community: nil,
        current_customer: customer
      )

      expect(resolved).to be_nil
    end

    it "reply_to_chat_message_idがnilの場合は拒否すること(通常投稿扱い)" do
      resolved = described_class.call(
        reply_to_chat_message_id: nil,
        chat_room: chat_room,
        community: nil,
        current_customer: customer
      )

      expect(resolved).to be_nil
    end

    it "コミュニティメッセージへの返信をDM文脈で送っても拒否すること" do
      community = create(:community)
      community_chat_room = create(:chat_room)
      original = create(:chat_message, customer: other_customer, chat_room: community_chat_room, community: community)

      resolved = described_class.call(
        reply_to_chat_message_id: original.id,
        chat_room: chat_room,
        community: nil,
        current_customer: customer
      )

      expect(resolved).to be_nil
    end
  end

  describe "コミュニティチャットメッセージへの返信" do
    let(:community) { create(:community) }
    let(:customer) { create(:customer) }
    let(:member) { create(:customer) }
    let(:chat_room) { create(:chat_room) }

    before do
      CommunityCustomer.find_or_create_by!(customer: customer, community: community)
      CommunityCustomer.find_or_create_by!(customer: member, community: community)
    end

    it "同じコミュニティ内のメッセージへの返信を許可すること" do
      original = create(:chat_message, customer: member, chat_room: chat_room, community: community)

      resolved = described_class.call(
        reply_to_chat_message_id: original.id,
        chat_room: chat_room,
        community: community,
        current_customer: customer
      )

      expect(resolved).to eq original
    end

    it "別のコミュニティのメッセージへの返信を拒否すること" do
      other_community = create(:community)
      other_chat_room = create(:chat_room)
      CommunityCustomer.find_or_create_by!(customer: customer, community: other_community)
      original = create(:chat_message, customer: member, chat_room: other_chat_room, community: other_community)

      resolved = described_class.call(
        reply_to_chat_message_id: original.id,
        chat_room: chat_room,
        community: community,
        current_customer: customer
      )

      expect(resolved).to be_nil
    end

    it "コミュニティメンバーでないcurrent_customerからの返信は拒否すること" do
      non_member = create(:customer)
      original = create(:chat_message, customer: member, chat_room: chat_room, community: community)

      resolved = described_class.call(
        reply_to_chat_message_id: original.id,
        chat_room: chat_room,
        community: community,
        current_customer: non_member
      )

      expect(resolved).to be_nil
    end
  end

  describe "スレッド親への正規化(Phase3)" do
    let(:customer) { create(:customer) }
    let(:other_customer) { create(:customer) }
    let(:chat_room) { create(:chat_room) }

    before do
      create(:chat_room_customer, chat_room: chat_room, customer: customer)
      create(:chat_room_customer, chat_room: chat_room, customer: other_customer)
    end

    it "返信先が既に返信メッセージだった場合、そのスレッドの親(thread_root)を返すこと" do
      root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿")
      reply = create(:chat_message, customer: customer, chat_room: chat_room,
                                     content: "返信です", reply_to_chat_message: root)

      resolved = described_class.call(
        reply_to_chat_message_id: reply.id,
        chat_room: chat_room,
        community: nil,
        current_customer: other_customer
      )

      expect(resolved).to eq root
    end

    it "返信先が通常メッセージ(スレッド親)だった場合はそのまま返すこと" do
      root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿")

      resolved = described_class.call(
        reply_to_chat_message_id: root.id,
        chat_room: chat_room,
        community: nil,
        current_customer: customer
      )

      expect(resolved).to eq root
    end
  end
end
