module Singing
  class MusicMilestonesBuilder
    Result = Struct.new(:active, :milestones, keyword_init: true) do
      def active?
        active == true
      end
    end

    Milestone = Struct.new(:icon, :title, :message, :occurred_at, keyword_init: true)

    LIMIT = 3

    def self.call(customer)
      new(customer).call
    end

    def initialize(customer)
      @customer = customer
    end

    def call
      return inactive if @customer.nil?

      earned = build_milestones
      return inactive if earned.blank?

      Result.new(active: true, milestones: earned)
    end

    private

    def build_milestones
      candidates = [
        first_diagnosis_milestone,
        ten_diagnoses_milestone,
        first_cheer_milestone,
        first_encouragement_milestone,
        first_challenge_milestone,
        streak_milestone
      ].compact

      candidates.sort_by { |m| -(m.occurred_at&.to_i || 0) }.first(LIMIT)
    end

    def first_diagnosis_milestone
      diagnosis = completed_diagnoses.order(:created_at).first
      return nil if diagnosis.nil?

      Milestone.new(
        icon: "🎤",
        title: "First Diagnosis",
        message: "初めて歌唱診断を行いました",
        occurred_at: diagnosis.created_at
      )
    rescue NoMethodError, ActiveRecord::StatementInvalid
      nil
    end

    def ten_diagnoses_milestone
      tenth = completed_diagnoses.order(:created_at).offset(9).first
      return nil if tenth.nil?

      Milestone.new(
        icon: "🔥",
        title: "Diagnosis Explorer",
        message: "10回の診断を達成しました",
        occurred_at: tenth.created_at
      )
    rescue NoMethodError, ActiveRecord::StatementInvalid
      nil
    end

    def first_cheer_milestone
      cheer = SingingCheerReaction.where(customer: @customer).order(:created_at).first
      return nil if cheer.nil?

      Milestone.new(
        icon: "👏",
        title: "First Cheer",
        message: "初めて仲間を応援しました",
        occurred_at: cheer.created_at
      )
    rescue NameError, ActiveRecord::StatementInvalid
      nil
    end

    def first_encouragement_milestone
      encouragement = SingingCheerReaction.where(target_customer_id: @customer.id).order(:created_at).first
      return nil if encouragement.nil?

      Milestone.new(
        icon: "🎉",
        title: "First Encouragement",
        message: "初めて仲間から応援されました",
        occurred_at: encouragement.created_at
      )
    rescue NameError, ActiveRecord::StatementInvalid
      nil
    end

    def first_challenge_milestone
      at = first_challenge_at
      return nil if at.nil?

      Milestone.new(
        icon: "🏆",
        title: "First Challenge",
        message: "初めてチャレンジに参加しました",
        occurred_at: at
      )
    end

    def first_challenge_at
      ai_at    = SingingAiChallengeProgress.where(customer: @customer).order(:created_at).first&.created_at
      daily_at = SingingDailyChallengeProgress.where(customer: @customer).order(:created_at).first&.created_at
      [ai_at, daily_at].compact.min
    rescue NameError, ActiveRecord::StatementInvalid
      nil
    end

    def streak_milestone
      return nil if current_streak < 7

      seventh = completed_diagnoses.order(created_at: :desc).offset(6).first
      occurred_at = seventh&.created_at || Time.current

      Milestone.new(
        icon: "🎵",
        title: "Consistency",
        message: "7日間の継続を達成しました",
        occurred_at: occurred_at
      )
    rescue NoMethodError, ActiveRecord::StatementInvalid
      nil
    end

    def completed_diagnoses
      @customer.singing_diagnoses.completed
    end

    def current_streak
      @current_streak ||= Singing::StreakCalculator.call(@customer)
    rescue NoMethodError, ActiveRecord::StatementInvalid
      0
    end

    def inactive
      Result.new(active: false, milestones: [])
    end
  end
end
