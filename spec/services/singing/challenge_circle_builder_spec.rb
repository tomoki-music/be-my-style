require "rails_helper"

RSpec.describe Singing::ChallengeCircleBuilder do
  describe ".call" do
    subject(:challenges) { described_class.call }

    it "6つのチャレンジを返す" do
      expect(challenges.size).to eq(6)
    end

    it "各チャレンジが必要なフィールドを持つ" do
      challenges.each do |c|
        expect(c.id).not_to be_nil
        expect(c.title).to be_a(String)
        expect(c.description).to be_a(String)
        expect(c.icon).to be_a(String)
        expect(c.start_date).to be_a(Time)
        expect(c.end_date).to be_a(Time)
        expect(c.target_value).to be_a(Integer)
        expect(c.challenge_type).to be_a(Symbol)
      end
    end

    it "participant_count が非負整数である" do
      challenges.each do |c|
        expect(c.participant_count).to be >= 0
      end
    end

    it "completion_count が非負整数である" do
      challenges.each do |c|
        expect(c.completion_count).to be >= 0
      end
    end

    it "streak_7 チャレンジが含まれる" do
      expect(challenges.map(&:id)).to include(:streak_7)
    end

    it "diagnosis_5 チャレンジが含まれる" do
      expect(challenges.map(&:id)).to include(:diagnosis_5)
    end

    it "theme チャレンジは premium_only? が true" do
      theme_challenge = challenges.find { |c| c.challenge_type == :theme }
      expect(theme_challenge).not_to be_nil
      expect(theme_challenge.premium_only?).to be true
    end

    it "theme 以外は premium_only? が false" do
      non_theme = challenges.reject { |c| c.challenge_type == :theme }
      expect(non_theme).to all(satisfy { |c| !c.premium_only? })
    end

    describe "completion_rate" do
      it "参加者がいないとき 0 を返す" do
        challenge = challenges.find { |c| c.id == :streak_7 }
        allow(challenge).to receive(:participant_count).and_return(0)
        allow(challenge).to receive(:completion_count).and_return(0)
        expect(challenge.completion_rate).to eq(0)
      end

      it "参加者が存在するとき 0-100 の範囲になる" do
        challenges.each do |c|
          expect(c.completion_rate).to be_between(0, 100)
        end
      end
    end
  end

  describe "community stats with data" do
    let(:customer1) { create(:customer, domain_name: "singing") }
    let(:customer2) { create(:customer, domain_name: "singing") }

    context "今週 5 回以上診断したユーザーがいるとき" do
      before do
        5.times { create(:singing_diagnosis, :completed, customer: customer1) }
      end

      it "diagnosis_5 の completion_count が 1 以上になる" do
        result = described_class.call
        diag5 = result.find { |c| c.id == :diagnosis_5 }
        expect(diag5.completion_count).to be >= 1
      end
    end
  end
end
