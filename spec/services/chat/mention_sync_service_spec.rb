require "rails_helper"

RSpec.describe Chat::MentionSyncService, type: :service do
  describe "DMメッセージ" do
    let(:customer) { create(:customer) }
    let(:other_customer) { create(:customer) }
    let(:chat_room) { create(:chat_room) }

    before do
      create(:chat_room_customer, chat_room: chat_room, customer: customer)
      create(:chat_room_customer, chat_room: chat_room, customer: other_customer)
    end

    it "アクセス権のある相手へのメンションでChatMentionと通知を作成すること" do
      chat_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room,
                                                        content: "[@相手](customer:#{other_customer.id}) こんにちは")

      expect { described_class.call(chat_message) }
        .to change(ChatMention, :count).by(1)
        .and change(Notification, :count).by(1)

      mention = ChatMention.last
      expect(mention.chat_message).to eq chat_message
      expect(mention.mentioned_customer).to eq other_customer

      notification = Notification.last
      expect(notification.action).to eq "mention_dm"
      expect(notification.visited_id).to eq other_customer.id
      expect(notification.visitor_id).to eq customer.id
      expect(notification.chat_message_id).to eq chat_message.id
    end

    it "同一メッセージで同じ相手を複数回メンションしてもChatMention・通知は1件だけ作成すること" do
      chat_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room,
                                                        content: "[@相手](customer:#{other_customer.id}) [@相手](customer:#{other_customer.id})")

      expect { described_class.call(chat_message) }
        .to change(ChatMention, :count).by(1)
        .and change(Notification, :count).by(1)
    end

    it "アクセス権のない(この部屋の参加者でない)ユーザーへのメンションは無視すること" do
      stranger = create(:customer)
      chat_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room,
                                                        content: "[@他人](customer:#{stranger.id}) こんにちは")

      expect { described_class.call(chat_message) }.not_to change { [ChatMention.count, Notification.count] }
    end

    it "存在しないcustomer_idへのメンションは無視すること" do
      chat_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room,
                                                        content: "[@誰か](customer:999999) こんにちは")

      expect { described_class.call(chat_message) }.not_to change { [ChatMention.count, Notification.count] }
    end

    it "自分自身へのメンションはChatMentionも通知も作成しないこと" do
      chat_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room,
                                                        content: "[@自分](customer:#{customer.id}) こんにちは")

      expect { described_class.call(chat_message) }.not_to change { [ChatMention.count, Notification.count] }
    end

    it "メンションが無い場合は何もしないこと" do
      chat_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, content: "こんにちは")

      expect { described_class.call(chat_message) }.not_to change { [ChatMention.count, Notification.count] }
    end

    it "skip_notification_customer_idsで指定した相手にはChatMentionは作成するが通知は作成しないこと(返信通知との重複抑制)" do
      chat_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room,
                                                        content: "[@相手](customer:#{other_customer.id}) こんにちは")

      expect {
        described_class.call(chat_message, skip_notification_customer_ids: [other_customer.id])
      }.to change(ChatMention, :count).by(1).and change(Notification, :count).by(0)
    end
  end

  describe "コミュニティチャットメッセージ" do
    let(:community) { create(:community) }
    let(:customer) { create(:customer) }
    let(:member) { create(:customer) }
    let(:chat_room) { create(:chat_room) }

    before do
      CommunityCustomer.find_or_create_by!(customer: customer, community: community)
      CommunityCustomer.find_or_create_by!(customer: member, community: community)
    end

    it "コミュニティメンバーへのメンションでChatMentionと通知(mention_community)を作成すること" do
      chat_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, community: community,
                                                        content: "[@メンバー](customer:#{member.id}) お願いします")

      expect { described_class.call(chat_message) }
        .to change(ChatMention, :count).by(1)
        .and change(Notification, :count).by(1)

      notification = Notification.last
      expect(notification.action).to eq "mention_community"
      expect(notification.community_id).to eq community.id
      expect(notification.chat_message_id).to eq chat_message.id
    end

    it "コミュニティメンバーでないユーザーへのメンションは無視すること" do
      non_member = create(:customer)
      chat_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, community: community,
                                                        content: "[@非メンバー](customer:#{non_member.id}) お願いします")

      expect { described_class.call(chat_message) }.not_to change { [ChatMention.count, Notification.count] }
    end

    it "複数ユーザーへのメンションをまとめて作成すること" do
      member2 = create(:customer)
      CommunityCustomer.find_or_create_by!(customer: member2, community: community)
      chat_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, community: community,
                                                        content: "[@A](customer:#{member.id}) [@B](customer:#{member2.id})")

      expect { described_class.call(chat_message) }.to change(ChatMention, :count).by(2)
    end
  end
end
