require "rails_helper"

RSpec.describe Singing::SuggestedMusiciansBuilder do
  def completed_diagnosis(customer, attrs = {})
    create(
      :singing_diagnosis,
      :completed,
      {
        customer: customer,
        overall_score: 75,
        pitch_score: 72,
        rhythm_score: 74,
        expression_score: 73,
        created_at: Time.current
      }.merge(attrs)
    )
  end

  def expression_pair(customer)
    completed_diagnosis(
      customer,
      overall_score: 70,
      pitch_score: 70,
      rhythm_score: 70,
      expression_score: 60,
      created_at: 2.days.ago
    )
    completed_diagnosis(
      customer,
      overall_score: 78,
      pitch_score: 71,
      rhythm_score: 70,
      expression_score: 82,
      created_at: 1.day.ago
    )
  end

  describe ".call" do
    it "ユーザーなしでは空のDTOを返す" do
      result = described_class.call(nil)

      expect(result).to be_a(described_class::SuggestedMusicians)
      expect(result.musicians).to eq([])
    end

    it "同じGrowth Typeの仲間を返す" do
      customer = create(:customer, domain_name: "singing")
      candidate = create(:customer, domain_name: "singing", name: "Yuki")
      completed_diagnosis(customer)
      completed_diagnosis(candidate)

      card = described_class.call(customer).musicians.first

      expect(card).to be_a(described_class::MusicianCard)
      expect(card.customer).to eq(candidate)
      expect(card.reason).to eq("同じGrowth Circleです")
      expect(card.profile_path).to eq("/singing/users/#{candidate.id}")
    end

    it "同じMissionの仲間を返す" do
      customer = create(:customer, domain_name: "singing")
      candidate = create(:customer, domain_name: "singing", name: "Miki")
      expression_pair(customer)
      completed_diagnosis(
        candidate,
        overall_score: 68,
        pitch_score: 80,
        rhythm_score: 70,
        expression_score: 70,
        created_at: 2.days.ago
      )
      completed_diagnosis(
        candidate,
        overall_score: 78,
        pitch_score: 82,
        rhythm_score: 80,
        expression_score: 88,
        created_at: 1.day.ago
      )

      card = described_class.call(customer).musicians.first

      expect(card.customer).to eq(candidate)
      expect(card.reason).to eq("同じテーマに挑戦しています")
    end

    it "音楽のつながりがある仲間を返す" do
      customer = create(:customer, domain_name: "singing")
      candidate = create(:customer, domain_name: "singing", name: "Ken")
      completed_diagnosis(candidate)
      create(:singing_cheer_reaction, customer: customer, target_customer: candidate)

      card = described_class.call(customer).musicians.first

      expect(card.customer).to eq(candidate)
      expect(card.reason).to eq("音楽のつながりがあります")
    end

    it "複数条件に当てはまる仲間を重複させない" do
      customer = create(:customer, domain_name: "singing")
      candidate = create(:customer, domain_name: "singing")
      completed_diagnosis(customer)
      completed_diagnosis(candidate)
      create(:singing_cheer_reaction, customer: customer, target_customer: candidate)

      result = described_class.call(customer)

      expect(result.musicians.map(&:customer)).to eq([candidate])
    end

    it "最大件数を制御する" do
      customer = create(:customer, domain_name: "singing")
      completed_diagnosis(customer)

      7.times do |index|
        candidate = create(:customer, domain_name: "singing", name: "Member#{index}")
        completed_diagnosis(candidate)
      end

      result = described_class.call(customer)

      expect(result.musicians.size).to eq(6)
    end

    it "limitが3未満でも3件まで表示できる" do
      customer = create(:customer, domain_name: "singing")
      completed_diagnosis(customer)

      3.times do |index|
        candidate = create(:customer, domain_name: "singing", name: "Friend#{index}")
        completed_diagnosis(candidate)
      end

      result = described_class.call(customer, limit: 1)

      expect(result.musicians.size).to eq(3)
    end

    it "nil安全" do
      expect { described_class.call(nil) }.not_to raise_error
    end
  end
end
