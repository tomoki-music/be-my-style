require "rails_helper"

RSpec.describe Chat::ReplyNotificationService, type: :service do
  describe "DMメッセージへの返信" do
    let(:customer) { create(:customer) }
    let(:other_customer) { create(:customer) }
    let(:chat_room) { create(:chat_room) }

    it "他人の投稿への返信でreply_dm通知を作成すること" do
      original = create(:chat_message, customer: other_customer, chat_room: chat_room)
      reply = create(:chat_message, customer: customer, chat_room: chat_room, reply_to_chat_message: original)

      expect { described_class.call(reply) }.to change(Notification, :count).by(1)

      notification = Notification.last
      expect(notification.action).to eq "reply_dm"
      expect(notification.visited_id).to eq other_customer.id
      expect(notification.visitor_id).to eq customer.id
      expect(notification.chat_message_id).to eq reply.id
    end

    it "自分自身の投稿への返信では通知を作成しないこと" do
      original = create(:chat_message, customer: customer, chat_room: chat_room)
      reply = create(:chat_message, customer: customer, chat_room: chat_room, reply_to_chat_message: original)

      expect { described_class.call(reply) }.not_to change(Notification, :count)
    end

    it "返信ではない(reply_to_chat_messageが無い)投稿では通知を作成しないこと" do
      message = create(:chat_message, customer: customer, chat_room: chat_room)

      expect { described_class.call(message) }.not_to change(Notification, :count)
    end

    it "通知した相手のcustomer_idを配列で返すこと" do
      original = create(:chat_message, customer: other_customer, chat_room: chat_room)
      reply = create(:chat_message, customer: customer, chat_room: chat_room, reply_to_chat_message: original)

      expect(described_class.call(reply)).to eq [other_customer.id]
    end

    it "自分自身への返信では空配列を返すこと" do
      original = create(:chat_message, customer: customer, chat_room: chat_room)
      reply = create(:chat_message, customer: customer, chat_room: chat_room, reply_to_chat_message: original)

      expect(described_class.call(reply)).to eq []
    end
  end

  describe "コミュニティチャットメッセージへの返信" do
    let(:community) { create(:community) }
    let(:customer) { create(:customer) }
    let(:member) { create(:customer) }
    let(:chat_room) { create(:chat_room) }

    it "他人の投稿への返信でreply_community通知を作成すること" do
      original = create(:chat_message, customer: member, chat_room: chat_room, community: community)
      reply = create(:chat_message, customer: customer, chat_room: chat_room, community: community,
                                     reply_to_chat_message: original)

      expect { described_class.call(reply) }.to change(Notification, :count).by(1)

      notification = Notification.last
      expect(notification.action).to eq "reply_community"
      expect(notification.community_id).to eq community.id
      expect(notification.chat_message_id).to eq reply.id
    end
  end
end
