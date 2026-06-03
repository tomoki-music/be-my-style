module Singing
  class PersonalMusicStoryBuilder
    Result = Struct.new(:active, :title, :story_lines, keyword_init: true) do
      def active?
        active == true
      end
    end

    TITLE = "あなたの音楽ストーリー".freeze
    LIMIT = 3

    def self.call(customer)
      new(customer).call
    end

    def initialize(customer)
      @customer = customer
    end

    def call
      return inactive if @customer.nil?

      lines = build_story_lines
      return inactive if lines.blank?

      Result.new(active: true, title: TITLE, story_lines: lines)
    end

    private

    def build_story_lines
      story_line_builders.each_with_object([]) do |builder, lines|
        line = builder.call
        lines << line if line.present?
        break lines if lines.size >= LIMIT
      end
    end

    def story_line_builders
      [
        method(:first_diagnosis_line),
        method(:streak_line),
        method(:reaction_line),
        method(:challenge_line),
        method(:community_line)
      ]
    end

    def first_diagnosis_line
      "🎤 初めて歌唱診断を行いました" if completed_diagnosis_exists?
    end

    def streak_line
      "🔥 7日継続を達成しました" if current_streak >= 7
    end

    def reaction_line
      "👏 仲間と応援を送り合いました" if reaction_activity_exists?
    end

    def challenge_line
      "🏆 チャレンジに挑戦しています" if challenge_activity_exists?
    end

    def community_line
      "🎸 仲間との音楽時間が増えています" if connected_customer_ids.size >= 2
    end

    def completed_diagnosis_exists?
      completed_diagnoses.exists?
    rescue NoMethodError, ActiveRecord::StatementInvalid
      false
    end

    def current_streak
      @current_streak ||= Singing::StreakCalculator.call(@customer)
    rescue NoMethodError, ActiveRecord::StatementInvalid
      0
    end

    def reaction_activity_exists?
      profile_reaction_activity_exists? || cheer_reaction_activity_exists?
    end

    def profile_reaction_activity_exists?
      SingingProfileReaction.where(customer: @customer).exists? ||
        SingingProfileReaction.where(target_customer_id: @customer.id).exists?
    rescue NameError, ActiveRecord::StatementInvalid
      false
    end

    def cheer_reaction_activity_exists?
      SingingCheerReaction.where(customer: @customer).exists? ||
        SingingCheerReaction.where(target_customer_id: @customer.id).exists?
    rescue NameError, ActiveRecord::StatementInvalid
      false
    end

    def challenge_activity_exists?
      ai_challenge_activity_exists? || daily_challenge_activity_exists?
    end

    def ai_challenge_activity_exists?
      SingingAiChallengeProgress
        .where(customer: @customer)
        .where("tried = ? OR completed = ? OR next_diagnosis_planned = ?", true, true, true)
        .exists?
    rescue NameError, ActiveRecord::StatementInvalid
      false
    end

    def daily_challenge_activity_exists?
      SingingDailyChallengeProgress.where(customer: @customer).exists?
    rescue NameError, ActiveRecord::StatementInvalid
      false
    end

    def connected_customer_ids
      @connected_customer_ids ||= (
        profile_reaction_customer_ids +
        cheer_reaction_customer_ids
      ).compact.uniq
    end

    def profile_reaction_customer_ids
      sent_ids = SingingProfileReaction.where(customer: @customer).pluck(:target_customer_id)
      received_ids = SingingProfileReaction.where(target_customer_id: @customer.id).pluck(:customer_id)
      sent_ids + received_ids
    rescue NameError, ActiveRecord::StatementInvalid
      []
    end

    def cheer_reaction_customer_ids
      sent_ids = SingingCheerReaction.where(customer: @customer).pluck(:target_customer_id)
      received_ids = SingingCheerReaction.where(target_customer_id: @customer.id).pluck(:customer_id)
      sent_ids + received_ids
    rescue NameError, ActiveRecord::StatementInvalid
      []
    end

    def completed_diagnoses
      @customer.singing_diagnoses.completed
    end

    def inactive
      Result.new(active: false, title: TITLE, story_lines: [])
    end
  end
end
