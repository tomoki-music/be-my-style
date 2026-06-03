require "rails_helper"

RSpec.describe Singing::EncouragementInboxBuilder do
  describe ".call" do
    context "customerがnilの場合" do
      it "空のInboxを返す" do
        inbox = described_class.call(customer: nil)
        expect(inbox.items).to be_empty
      end
    end

    context "応援がない場合" do
      let(:customer) { create(:customer, domain_name: "singing") }

      it "空のInboxを返す" do
        inbox = described_class.call(customer: customer)
        expect(inbox.items).to be_empty
      end
    end

    context "応援がある場合" do
      let(:customer) { create(:customer, domain_name: "singing") }
      let(:sender1)  { create(:customer, domain_name: "singing") }
      let(:sender2)  { create(:customer, domain_name: "singing") }

      before do
        create(:singing_profile_reaction, customer: sender1, target_customer: customer, reaction_type: "cheer")
        create(:singing_profile_reaction, customer: sender2, target_customer: customer, reaction_type: "amazing")
      end

      it "InboxItemを返す" do
        inbox = described_class.call(customer: customer)
        expect(inbox.items.size).to eq(2)
      end

      it "各itemにcustomer・reaction_type・message・icon・occurred_atが設定されている" do
        inbox = described_class.call(customer: customer)
        item = inbox.items.first
        expect(item.customer).to be_a(Customer)
        expect(item.reaction_type).to be_present
        expect(item.message).to be_present
        expect(item.icon).to be_present
        expect(item.occurred_at).to be_present
      end

      it "customer.nameがblankでもitemを作成できる" do
        sender1.update_column(:name, "")

        inbox = described_class.call(customer: customer)
        item = inbox.items.find { |i| i.customer.id == sender1.id }

        expect(item).to be_present
        expect(item.customer).to be_a(Customer)
        expect(item.customer.name).to be_blank
      end

      it "最新順（created_at DESC）にソートされている" do
        inbox = described_class.call(customer: customer)
        times = inbox.items.map(&:occurred_at)
        expect(times).to eq(times.sort.reverse)
      end
    end

    context "reaction_type変換" do
      let(:customer) { create(:customer, domain_name: "singing") }

      SingingProfileReaction::REACTION_TYPES.each do |rt|
        it "#{rt}のiconとmessageが正しく設定されている" do
          sender = create(:customer, domain_name: "singing")
          create(:singing_profile_reaction, customer: sender, target_customer: customer, reaction_type: rt)
          inbox = described_class.call(customer: customer)
          item = inbox.items.first
          expect(item.icon).not_to be_nil
          expect(item.message).not_to be_nil
          expect(item.reaction_type).to eq(rt)
        end
      end
    end

    context "最大5件制限" do
      let(:customer) { create(:customer, domain_name: "singing") }

      it "6件以上でも5件以下に制限される" do
        6.times do
          sender = create(:customer, domain_name: "singing")
          create(:singing_profile_reaction, customer: sender, target_customer: customer, reaction_type: "cheer")
        end
        inbox = described_class.call(customer: customer)
        expect(inbox.items.size).to be <= 5
      end
    end

    context "nil安全" do
      it "StandardErrorが発生しても空のInboxを返す" do
        customer = create(:customer, domain_name: "singing")
        allow(SingingProfileReaction).to receive(:where).and_raise(StandardError)
        inbox = described_class.call(customer: customer)
        expect(inbox.items).to be_empty
      end
    end
  end
end
