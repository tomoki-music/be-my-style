require "rails_helper"

RSpec.describe Singing::MissionGenerator do
  let(:customer) { create(:customer, domain_name: "singing") }

  def create_completed_diagnoses(count)
    count.times do |i|
      create(:singing_diagnosis, :completed, customer: customer, created_at: i.days.ago)
    end
  end

  def challenge(id:, type:)
    Singing::ChallengeCircleBuilder::Challenge.new(
      id: id,
      title: id.to_s,
      description: "description",
      icon: "🎤",
      start_date: Time.current.beginning_of_week,
      end_date: Time.current.end_of_week,
      target_value: 3,
      challenge_type: type,
      participant_count: 0,
      completion_count: 0
    )
  end

  def progress_for(challenge, current: 1)
    Singing::ChallengeProgressBuilder::Progress.new(
      challenge: challenge,
      current_value: current,
      target_value: challenge.target_value,
      progress_ratio: current.to_f / challenge.target_value,
      completed: false
    )
  end

  def growth_type(type_key)
    info = Singing::GrowthTypeAnalyzer::GROWTH_TYPES.fetch(type_key)
    Singing::GrowthTypeAnalyzer::Result.new(
      type_key: type_key,
      label: info[:label],
      icon: info[:icon],
      description: info[:description]
    )
  end

  describe ".call" do
    it "customer nilでも生成される" do
      mission = described_class.call(nil)

      expect(mission).to be_a(described_class::Mission)
      expect(mission.title).to be_present
    end

    it "診断0件でも生成される" do
      mission = described_class.call(customer, progresses: [])

      expect(mission).to be_a(described_class::Mission)
      expect(mission.title).to eq("今月最初の一歩")
    end

    it "Mission DTOが返り、必須テキストが空にならない" do
      mission = described_class.call(customer, progresses: [])

      expect(mission.title).to be_present
      expect(mission.description).to be_present
      expect(mission.reason).to be_present
      expect(mission.coach_message).to be_present
      expect(mission.difficulty).to be_present
      expect(mission.recommended_score).to be_between(0, 100)
    end

    it "診断回数が少ない場合は継続ミッションを返す" do
      create_completed_diagnoses(1)

      mission = described_class.call(customer, progresses: [])

      expect(mission.title).to eq("1分だけ歌おう")
      expect(mission.reason).to include("診断回数")
    end

    it "GrowthType別に変化する" do
      create_completed_diagnoses(3)

      emotional = described_class.call(customer, progresses: [], growth_type: growth_type(:emotional_singer))
      rhythm = described_class.call(customer, progresses: [], growth_type: growth_type(:rhythm_explorer))

      expect(emotional.title).to eq("感情を1つ決めて歌おう")
      expect(rhythm.title).to eq("リズムに乗ってみよう")
      expect(emotional.description).not_to eq(rhythm.description)
    end

    it "RecommendedJourneyがある場合は反映される" do
      create_completed_diagnoses(3)
      expression_challenge = challenge(id: :expression_growth, type: :expression_growth)
      progress = progress_for(expression_challenge, current: 2)
      recommended = Singing::RecommendedJourneyBuilder::Result.new(
        challenge: expression_challenge,
        progress: progress,
        coach_label: "優しい先生",
        coach_icon: "🌿",
        title: "表現の色を増やそう",
        message: "message",
        reason: "ここを伸ばすと、自分らしい歌の手応えが増えそうです。",
        action_label: "続きを進める"
      )

      mission = described_class.call(customer, recommended_journey: recommended, progresses: [progress])

      expect(mission.title).to eq("感情を1つ決めて歌おう")
      expect(mission.reason).to eq("ここを伸ばすと、自分らしい歌の手応えが増えそうです。")
    end

    it "nil安全" do
      expect { described_class.call(nil, recommended_journey: nil, roadmap: nil, progresses: nil, growth_type: nil) }.not_to raise_error
    end
  end
end
