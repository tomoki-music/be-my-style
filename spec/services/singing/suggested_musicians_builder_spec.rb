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
      expect(card.reacted).to eq(false)
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

    it "current_customer nilでもreacted falseを返す" do
      customer = create(:customer, domain_name: "singing")
      candidate = create(:customer, domain_name: "singing")
      completed_diagnosis(customer)
      completed_diagnosis(candidate)

      card = described_class.call(customer, current_customer: nil).musicians.first

      expect(card.reacted).to eq(false)
    end

    it "current_customer が未応援の場合は reacted false を返す" do
      customer = create(:customer, domain_name: "singing")
      candidate = create(:customer, domain_name: "singing")
      completed_diagnosis(customer)
      completed_diagnosis(candidate)

      card = described_class.call(customer, current_customer: customer).musicians.first

      expect(card.customer).to eq(candidate)
      expect(card.reacted).to eq(false)
    end

    it "応援済みなら reacted true を返す" do
      customer = create(:customer, domain_name: "singing")
      candidate = create(:customer, domain_name: "singing")
      completed_diagnosis(customer)
      completed_diagnosis(candidate)
      create(:singing_profile_reaction, customer: customer, target_customer: candidate, reaction_type: "cheer")

      card = described_class.call(customer, current_customer: customer).musicians.first

      expect(card.customer).to eq(candidate)
      expect(card.reacted).to eq(true)
    end

    it "cheer以外のリアクションは reacted false のまま" do
      customer = create(:customer, domain_name: "singing")
      candidate = create(:customer, domain_name: "singing")
      completed_diagnosis(customer)
      completed_diagnosis(candidate)
      create(:singing_profile_reaction, customer: customer, target_customer: candidate, reaction_type: "amazing")

      card = described_class.call(customer, current_customer: customer).musicians.first

      expect(card.reacted).to eq(false)
    end

    it "reacted 判定は SingingProfileReaction への一括取得で行う" do
      customer = create(:customer, domain_name: "singing")
      completed_diagnosis(customer)

      candidates = 3.times.map do
        candidate = create(:customer, domain_name: "singing")
        completed_diagnosis(candidate)
        candidate
      end
      create(:singing_profile_reaction, customer: customer, target_customer: candidates.first, reaction_type: "cheer")

      reaction_query_count = 0
      callback = lambda do |_name, _started, _finished, _id, payload|
        sql = payload[:sql].to_s
        reaction_query_count += 1 if sql.include?("singing_profile_reactions")
      end

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        described_class.call(customer, current_customer: customer)
      end

      expect(reaction_query_count).to eq(1)
    end

    it "自分自身は候補から除外する" do
      customer = create(:customer, domain_name: "singing")
      completed_diagnosis(customer)

      result = described_class.call(customer, current_customer: customer)

      expect(result.musicians.map(&:customer)).not_to include(customer)
    end
  end
end
