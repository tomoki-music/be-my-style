require "rails_helper"

RSpec.describe Chat::QuoteTargetResolver, type: :service do
  describe "DMメッセージの引用" do
    let(:customer) { create(:customer) }
    let(:other_customer) { create(:customer) }
    let(:chat_room) { create(:chat_room) }

    before do
      create(:chat_room_customer, chat_room: chat_room, customer: customer)
      create(:chat_room_customer, chat_room: chat_room, customer: other_customer)
    end

    it "同じchat_room内のメッセージの引用を許可すること" do
      original = create(:chat_message, customer: other_customer, chat_room: chat_room)

      resolved = described_class.call(
        quoted_chat_message_id: original.id,
        chat_room: chat_room,
        community: nil,
        current_customer: customer
      )

      expect(resolved).to eq original
    end

    it "自分自身の投稿も引用できること" do
      original = create(:chat_message, customer: customer, chat_room: chat_room)

      resolved = described_class.call(
        quoted_chat_message_id: original.id,
        chat_room: chat_room,
        community: nil,
        current_customer: customer
      )

      expect(resolved).to eq original
    end

    it "別のchat_room(別DM)のメッセージの引用を拒否すること" do
      other_chat_room = create(:chat_room)
      create(:chat_room_customer, chat_room: other_chat_room, customer: customer)
      original = create(:chat_message, customer: other_customer, chat_room: other_chat_room)

      resolved = described_class.call(
        quoted_chat_message_id: original.id,
        chat_room: chat_room,
        community: nil,
        current_customer: customer
      )

      expect(resolved).to be_nil
    end

    it "現在のchat_roomの参加者でないcurrent_customerからの引用は拒否すること" do
      stranger = create(:customer)
      original = create(:chat_message, customer: other_customer, chat_room: chat_room)

      resolved = described_class.call(
        quoted_chat_message_id: original.id,
        chat_room: chat_room,
        community: nil,
        current_customer: stranger
      )

      expect(resolved).to be_nil
    end

    it "存在しないquoted_chat_message_idは拒否すること" do
      resolved = described_class.call(
        quoted_chat_message_id: 999_999,
        chat_room: chat_room,
        community: nil,
        current_customer: customer
      )

      expect(resolved).to be_nil
    end

    it "quoted_chat_message_idがnilの場合は拒否すること(引用なし投稿扱い)" do
      resolved = described_class.call(
        quoted_chat_message_id: nil,
        chat_room: chat_room,
        community: nil,
        current_customer: customer
      )

      expect(resolved).to be_nil
    end

    it "コミュニティメッセージの引用をDM文脈で行っても拒否すること" do
      community = create(:community)
      community_chat_room = create(:chat_room)
      original = create(:chat_message, customer: other_customer, chat_room: community_chat_room, community: community)

      resolved = described_class.call(
        quoted_chat_message_id: original.id,
        chat_room: chat_room,
        community: nil,
        current_customer: customer
      )

      expect(resolved).to be_nil
    end

    it "スレッド内の返信メッセージ自体を、スレッド親へ正規化せずそのまま引用できること(Chat::ReplyTargetResolverとの違い)" do
      root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿")
      thread_reply = create(:chat_message, customer: customer, chat_room: chat_room,
                                            content: "スレッド内の返信", reply_to_chat_message: root)

      resolved = described_class.call(
        quoted_chat_message_id: thread_reply.id,
        chat_room: chat_room,
        community: nil,
        current_customer: other_customer
      )

      expect(resolved).to eq thread_reply
      expect(resolved).not_to eq root
    end
  end

  describe "コミュニティチャットメッセージの引用" do
    let(:community) { create(:community) }
    let(:customer) { create(:customer) }
    let(:member) { create(:customer) }
    let(:chat_room) { create(:chat_room) }

    before do
      CommunityCustomer.find_or_create_by!(customer: customer, community: community)
      CommunityCustomer.find_or_create_by!(customer: member, community: community)
    end

    it "同じコミュニティ内のメッセージの引用を許可すること" do
      original = create(:chat_message, customer: member, chat_room: chat_room, community: community)

      resolved = described_class.call(
        quoted_chat_message_id: original.id,
        chat_room: chat_room,
        community: community,
        current_customer: customer
      )

      expect(resolved).to eq original
    end

    it "別のコミュニティのメッセージの引用を拒否すること" do
      other_community = create(:community)
      other_chat_room = create(:chat_room)
      CommunityCustomer.find_or_create_by!(customer: customer, community: other_community)
      original = create(:chat_message, customer: member, chat_room: other_chat_room, community: other_community)

      resolved = described_class.call(
        quoted_chat_message_id: original.id,
        chat_room: chat_room,
        community: community,
        current_customer: customer
      )

      expect(resolved).to be_nil
    end

    it "コミュニティメンバーでないcurrent_customerからの引用は拒否すること" do
      non_member = create(:customer)
      original = create(:chat_message, customer: member, chat_room: chat_room, community: community)

      resolved = described_class.call(
        quoted_chat_message_id: original.id,
        chat_room: chat_room,
        community: community,
        current_customer: non_member
      )

      expect(resolved).to be_nil
    end
  end
end
