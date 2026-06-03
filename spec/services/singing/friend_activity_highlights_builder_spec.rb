require "rails_helper"

RSpec.describe Singing::FriendActivityHighlightsBuilder do
  describe ".call" do
    let(:customer) { create(:customer, domain_name: "singing") }

    def connect_friend(friend, occurred_at: 3.days.ago)
      create(:singing_profile_reaction, customer: customer, target_customer: friend, created_at: occurred_at)
    end

    it "friend diagnosis を返す" do
      friend = create(:customer, domain_name: "singing", name: "山田")
      connect_friend(friend)
      create(:singing_diagnosis, :completed, customer: friend, created_at: 1.hour.ago, diagnosed_at: 1.hour.ago)

      result = described_class.call(customer)

      expect(result).to be_active
      expect(result.highlights.first.customer_id).to eq(friend.id)
      expect(result.highlights.first.icon).to eq("🎤")
      expect(result.highlights.first.message).to eq("山田さんが最近、歌唱診断を完了しました")
      expect(result.highlights.first.profile_path).to eq("/singing/users/#{friend.id}")
    end

    it "friend reaction を返す" do
      friend = create(:customer, domain_name: "singing", name: "鈴木")
      connect_friend(friend, occurred_at: 3.days.ago)
      create(:singing_profile_reaction,
             customer: friend,
             target_customer: create(:customer, domain_name: "singing"),
             reaction_type: "growth",
             created_at: 1.hour.ago)

      result = described_class.call(customer)

      expect(result.highlights.first.icon).to eq("🔥")
      expect(result.highlights.first.message).to eq("鈴木さんが仲間を応援しました")
    end

    it "friend challenge progress を返す" do
      friend = create(:customer, domain_name: "singing", name: "田中")
      connect_friend(friend)
      create(:singing_ai_challenge_progress,
             customer: friend,
             tried: true,
             updated_at: 1.hour.ago)

      result = described_class.call(customer)

      expect(result.highlights.first.icon).to eq("🏆")
      expect(result.highlights.first.message).to eq("田中さんがチャレンジを進めています")
    end

    it "mixed highlights を直近順で返す" do
      diagnosis_friend = create(:customer, domain_name: "singing", name: "診断")
      reaction_friend = create(:customer, domain_name: "singing", name: "応援")
      challenge_friend = create(:customer, domain_name: "singing", name: "挑戦")
      [diagnosis_friend, reaction_friend, challenge_friend].each { |friend| connect_friend(friend, occurred_at: 5.days.ago) }

      create(:singing_diagnosis, :completed, customer: diagnosis_friend, created_at: 3.hours.ago, diagnosed_at: 3.hours.ago)
      create(:singing_profile_reaction,
             customer: reaction_friend,
             target_customer: create(:customer, domain_name: "singing"),
             reaction_type: "listen",
             created_at: 1.hour.ago)
      create(:singing_ai_challenge_progress, customer: challenge_friend, tried: true, updated_at: 2.hours.ago)

      result = described_class.call(customer)

      expect(result.highlights.map(&:customer_id)).to eq([
        reaction_friend.id,
        challenge_friend.id,
        diagnosis_friend.id
      ])
    end

    it "最大3件まで返す" do
      friends = create_list(:customer, 4, domain_name: "singing")
      friends.each_with_index do |friend, index|
        create(:singing_profile_reaction,
               customer: customer,
               target_customer: friend,
               reaction_type: SingingProfileReaction::REACTION_TYPES[index],
               created_at: 5.days.ago)
        create(:singing_diagnosis,
               :completed,
               customer: friend,
               created_at: (index + 1).hours.ago,
               diagnosed_at: (index + 1).hours.ago)
      end

      result = described_class.call(customer)

      expect(result.highlights.size).to eq(3)
    end

    it "friends がない場合は非アクティブ" do
      result = described_class.call(customer)

      expect(result).not_to be_active
      expect(result.highlights).to eq([])
    end

    it "activity がない場合は非アクティブ" do
      friend = create(:customer, domain_name: "singing")
      connect_friend(friend)

      result = described_class.call(customer)

      expect(result).not_to be_active
      expect(result.highlights).to eq([])
    end

    it "customer nilでも非アクティブ" do
      result = described_class.call(nil)

      expect(result).not_to be_active
      expect(result.highlights).to eq([])
    end
  end
end
