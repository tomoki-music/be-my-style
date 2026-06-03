require "rails_helper"

RSpec.describe Singing::MusicFriendsBuilder do
  describe ".call" do
    it "送ったプロフィールリアクションから仲間を返す" do
      customer = create(:customer, domain_name: "singing")
      friend = create(:customer, domain_name: "singing", name: "山田")
      create(:singing_profile_reaction, customer: customer, target_customer: friend)

      result = described_class.call(customer)

      expect(result).to be_active
      expect(result.friends.first.customer_id).to eq(friend.id)
      expect(result.friends.first.display_name).to eq("山田")
      expect(result.friends.first.message).to eq("最近あなたが応援した仲間です")
      expect(result.friends.first.profile_path).to eq("/singing/users/#{friend.id}")
    end

    it "受け取ったプロフィールリアクションから仲間を返す" do
      customer = create(:customer, domain_name: "singing")
      friend = create(:customer, domain_name: "singing", name: "鈴木")
      create(:singing_profile_reaction, customer: friend, target_customer: customer)

      result = described_class.call(customer)

      expect(result.friends.first.customer_id).to eq(friend.id)
      expect(result.friends.first.message).to eq("最近あなたを応援してくれた仲間です")
    end

    it "送受信が混ざる場合はやり取りメッセージを返す" do
      customer = create(:customer, domain_name: "singing")
      friend = create(:customer, domain_name: "singing")
      create(:singing_profile_reaction, customer: customer, target_customer: friend, reaction_type: "cheer")
      create(:singing_profile_reaction, customer: friend, target_customer: customer, reaction_type: "listen")

      result = described_class.call(customer)

      expect(result.friends.first.customer_id).to eq(friend.id)
      expect(result.friends.first.message).to eq("応援のやり取りがありました")
    end

    it "同じ仲間との複数接点は重複しない" do
      customer = create(:customer, domain_name: "singing")
      friend = create(:customer, domain_name: "singing")
      create(:singing_profile_reaction, customer: customer, target_customer: friend, reaction_type: "cheer")
      create(:singing_profile_reaction, customer: customer, target_customer: friend, reaction_type: "growth")
      create(:singing_profile_reaction, customer: friend, target_customer: customer, reaction_type: "listen")

      result = described_class.call(customer)

      expect(result.friends.map(&:customer_id)).to eq([friend.id])
    end

    it "最大3人まで返す" do
      customer = create(:customer, domain_name: "singing")
      friends = create_list(:customer, 4, domain_name: "singing")
      friends.each_with_index do |friend, index|
        create(:singing_profile_reaction, customer: customer, target_customer: friend, reaction_type: SingingProfileReaction::REACTION_TYPES[index])
      end

      result = described_class.call(customer)

      expect(result.friends.size).to eq(3)
    end

    it "データがない場合は非アクティブ" do
      customer = create(:customer, domain_name: "singing")

      result = described_class.call(customer)

      expect(result).not_to be_active
      expect(result.friends).to eq([])
    end

    it "customer nilでも非アクティブで返す" do
      result = described_class.call(nil)

      expect(result).not_to be_active
      expect(result.friends).to eq([])
    end
  end
end
