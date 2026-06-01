require "rails_helper"

RSpec.describe Singing::RecommendedJourneyBuilder do
  let(:customer) { build(:customer, domain_name: "singing", singing_coach_personality: :gentle) }

  def challenge(id:, type:, premium: false)
    Singing::ChallengeCircleBuilder::Challenge.new(
      id: id,
      title: id.to_s,
      description: "description",
      icon: "🎤",
      start_date: Time.current.beginning_of_week,
      end_date: Time.current.end_of_week,
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
    context "customer が nil のとき" do
      it "nil を返す" do
        expect(described_class.call(nil, progresses: [])).to be_nil
      end
    end

    context "progresses が空配列のとき" do
      it "nil を返す" do
        expect(described_class.call(customer, progresses: [])).to be_nil
      end
    end

    it "未達成の中で進んでいるチャレンジを1件おすすめする" do
      diagnosis = challenge(id: :diagnosis_5, type: :diagnosis_count)
      rhythm = challenge(id: :rhythm_growth, type: :rhythm_growth)
      progresses = [
        progress_for(diagnosis, current: 1),
        progress_for(rhythm, current: 2, target: 3)
      ]

      result = described_class.call(customer, progresses: progresses)

      expect(result.challenge).to eq(rhythm)
      expect(result.progress).to eq(progresses.last)
      expect(result.reason).to include("2 / 3")
    end

    it "完了済みチャレンジは候補から外す" do
      completed = challenge(id: :diagnosis_5, type: :diagnosis_count)
      next_challenge = challenge(id: :streak_7, type: :streak)
      progresses = [
        progress_for(completed, current: 5, completed: true),
        progress_for(next_challenge, current: 0, target: 7)
      ]

      result = described_class.call(customer, progresses: progresses)

      expect(result.challenge).to eq(next_challenge)
    end

    it "Premium未許可では theme チャレンジを候補から外す" do
      theme = challenge(id: :anison_month, type: :theme, premium: true)
      diagnosis = challenge(id: :diagnosis_5, type: :diagnosis_count)
      progresses = [
        progress_for(theme, current: 2, target: 3),
        progress_for(diagnosis, current: 0)
      ]

      result = described_class.call(customer, progresses: progresses, include_premium: false)

      expect(result.challenge).to eq(diagnosis)
    end

    it "Premium許可では theme チャレンジも候補に含める" do
      theme = challenge(id: :anison_month, type: :theme, premium: true)
      diagnosis = challenge(id: :diagnosis_5, type: :diagnosis_count)
      progresses = [
        progress_for(theme, current: 2, target: 3),
        progress_for(diagnosis, current: 0)
      ]

      result = described_class.call(customer, progresses: progresses, include_premium: true)

      expect(result.challenge).to eq(theme)
    end

    it "コーチ人格のラベルと前向きな文言を返す" do
      diagnosis = challenge(id: :diagnosis_5, type: :diagnosis_count)
      result = described_class.call(customer, progresses: [progress_for(diagnosis, current: 0)])

      expect(result.coach_label).to eq("優しい先生")
      expect(result.coach_icon).to eq("🌿")
      expect(result.title).to be_present
      expect(result.message).to include("見つ")
      expect(result.action_label).to eq("この挑戦を始める")
    end

    it "全チャレンジ達成済みなら nil を返す" do
      diagnosis = challenge(id: :diagnosis_5, type: :diagnosis_count)
      progresses = [progress_for(diagnosis, current: 5, completed: true)]

      expect(described_class.call(customer, progresses: progresses)).to be_nil
    end
  end
end
