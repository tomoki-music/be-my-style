require "rails_helper"

RSpec.describe Singing::PersonalMusicStoryBuilder do
  describe ".call" do
    let(:customer) { create(:customer, domain_name: "singing") }

    it "nil customerではinactiveを返す" do
      result = described_class.call(nil)

      expect(result).not_to be_active
      expect(result.title).to eq("あなたの音楽ストーリー")
      expect(result.story_lines).to eq([])
    end

    it "活動がない場合はinactiveを返す" do
      result = described_class.call(customer)

      expect(result).not_to be_active
      expect(result.story_lines).to eq([])
    end

    it "初回診断のストーリーを返す" do
      create(:singing_diagnosis, :completed, customer: customer)

      result = described_class.call(customer)

      expect(result).to be_active
      expect(result.story_lines).to include("🎤 初めて歌唱診断を行いました")
    end

    it "応援活動のストーリーを返す" do
      create(:singing_profile_reaction, customer: customer)

      result = described_class.call(customer)

      expect(result).to be_active
      expect(result.story_lines).to include("👏 仲間と応援を送り合いました")
    end

    it "チャレンジ活動のストーリーを返す" do
      create(:singing_ai_challenge_progress, customer: customer, tried: true)

      result = described_class.call(customer)

      expect(result).to be_active
      expect(result.story_lines).to include("🏆 チャレンジに挑戦しています")
    end

    it "複数のストーリーを返す" do
      create(:singing_diagnosis, :completed, customer: customer)
      create(:singing_profile_reaction, customer: customer)
      create(:singing_ai_challenge_progress, customer: customer, tried: true)

      result = described_class.call(customer)

      expect(result.story_lines).to include(
        "🎤 初めて歌唱診断を行いました",
        "👏 仲間と応援を送り合いました",
        "🏆 チャレンジに挑戦しています"
      )
    end

    it "7日継続のストーリーを返す" do
      7.times do |index|
        create(:singing_diagnosis, :completed, customer: customer, created_at: index.days.ago)
      end

      result = described_class.call(customer)

      expect(result.story_lines).to include("🔥 7日継続を達成しました")
    end

    it "story_linesを最大3件に制限する" do
      connected_customers = create_list(:customer, 2, domain_name: "singing")
      7.times do |index|
        create(:singing_diagnosis, :completed, customer: customer, created_at: index.days.ago)
      end
      create(:singing_profile_reaction, customer: customer, target_customer: connected_customers[0])
      create(:singing_profile_reaction, customer: connected_customers[1], target_customer: customer)
      create(:singing_ai_challenge_progress, customer: customer, tried: true)

      result = described_class.call(customer)

      expect(result.story_lines.size).to eq(3)
    end
  end
end
