require "rails_helper"

RSpec.describe Singing::PersonalGrowthRoadmapBuilder do
  let(:customer) { create(:customer, domain_name: "singing", singing_coach_personality: :gentle) }

  def challenge(id:, type:, premium: false)
    Singing::ChallengeCircleBuilder::Challenge.new(
      id: id,
      title: id.to_s,
      description: "description",
      icon: "🎤",
      start_date: Time.current.beginning_of_month,
      end_date: Time.current.end_of_month,
      target_value: 5,
      challenge_type: premium ? :theme : type,
      participant_count: 0,
      completion_count: 0
    )
  end

  def progress_for(challenge, current:, target: nil, completed: false)
    target ||= challenge.target_value
    ratio = target.to_i.zero? ? 0.0 : [(current.to_f / target), 1.0].min

    Singing::ChallengeProgressBuilder::Progress.new(
      challenge: challenge,
      current_value: current,
      target_value: target,
      progress_ratio: ratio,
      completed: completed
    )
  end

  describe ".call" do
    context "診断データがないとき" do
      it "Roadmapを返す" do
        roadmap = described_class.call(customer, progresses: [])

        expect(roadmap).to be_a(described_class::Roadmap)
        expect(roadmap.title).to be_present
        expect(roadmap.coach_message).to be_present
      end
    end

    it "stepsを3件返す" do
      roadmap = described_class.call(customer, progresses: [])

      expect(roadmap.steps.size).to eq(3)
    end

    it "各stepにnumber/title/description/statusがある" do
      roadmap = described_class.call(customer, progresses: [])

      roadmap.steps.each do |step|
        expect(step.number).to be_a(Integer)
        expect(step.title).to be_present
        expect(step.description).to be_present
        expect(step.status).to be_present
      end
    end

    it "RecommendedJourneyBuilderの結果を利用できる" do
      rhythm = challenge(id: :rhythm_growth, type: :rhythm_growth)
      progress = progress_for(rhythm, current: 1, target: 3)
      recommended = Singing::RecommendedJourneyBuilder::Result.new(
        challenge: rhythm,
        progress: progress,
        coach_label: "優しい先生",
        coach_icon: "🌿",
        title: "リズムに乗る楽しさを広げよう",
        message: "message",
        reason: "今はリズムを育てる挑戦が合いそうです。",
        action_label: "続きを進める"
      )

      create(:singing_diagnosis, :completed, customer: customer)
      roadmap = described_class.call(customer, progresses: [progress], recommended_journey: recommended)

      expect(roadmap.steps.map(&:challenge_key)).to include(:rhythm_growth)
      expect(roadmap.steps.map(&:description)).to include("今はリズムを育てる挑戦が合いそうです。")
    end

    it "Premium限定導線がFreeで強く出すぎない" do
      theme = challenge(id: :anison_month, type: :theme, premium: true)
      progresses = [progress_for(theme, current: 2, target: 3)]

      roadmap = described_class.call(customer, progresses: progresses, include_premium: false)
      text = ([roadmap.title, roadmap.subtitle, roadmap.coach_message] + roadmap.steps.flat_map { |s| [s.title, s.description] }).join

      expect(text).not_to include("Premium")
      expect(roadmap.steps.map(&:challenge_key)).not_to include(:anison_month)
    end

    it "全チャレンジ達成済みでもnilにならない" do
      diagnosis = challenge(id: :diagnosis_5, type: :diagnosis_count)
      streak = challenge(id: :streak_7, type: :streak)
      progresses = [
        progress_for(diagnosis, current: 5, completed: true),
        progress_for(streak, current: 7, target: 7, completed: true)
      ]

      roadmap = described_class.call(customer, progresses: progresses)

      expect(roadmap).to be_a(described_class::Roadmap)
      expect(roadmap.steps.size).to eq(3)
      expect(roadmap.steps.first.status).to eq(:completed)
      expect(roadmap.steps.map(&:challenge_key)).to include(:monthly_reflection)
    end

    context "customer が nil のとき" do
      it "Roadmapを返す" do
        roadmap = described_class.call(nil, progresses: [])

        expect(roadmap).to be_a(described_class::Roadmap)
        expect(roadmap.steps.size).to eq(3)
      end
    end
  end
end
