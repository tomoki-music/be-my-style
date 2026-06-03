module Singing
  class ActivitySignalBuilder
    Result = Struct.new(:active, :latest_signal, :signals, keyword_init: true) do
      def active?
        active == true
      end
    end

    Signal = Struct.new(
      :source,
      :occurred_at,
      :target_customer_id,
      :metadata,
      keyword_init: true
    )

    def self.call(customer)
      new(customer).call
    end

    def initialize(customer)
      @customer = customer
    end

    def call
      return inactive if @customer.nil?

      sorted_signals = signals.compact.select { |signal| signal.occurred_at.present? }.sort_by(&:occurred_at).reverse

      Result.new(
        active: sorted_signals.any?,
        latest_signal: sorted_signals.first,
        signals: sorted_signals
      )
    end

    private

    def signals
      [
        diagnosis_signal,
        reaction_sent_signal,
        reaction_received_signal,
        challenge_progress_signals
      ].flatten
    end

    def diagnosis_signal
      diagnosis = SingingDiagnosis.completed.where(customer: @customer).order(created_at: :desc, id: :desc).first
      return if diagnosis.nil?

      Signal.new(
        source: :diagnosis,
        occurred_at: timestamp_for(diagnosis, :completed_at, :created_at, :updated_at),
        target_customer_id: nil,
        metadata: {}
      )
    rescue NameError, NoMethodError, ActiveRecord::StatementInvalid
      nil
    end

    def reaction_sent_signal
      reaction = SingingProfileReaction.where(customer: @customer).order(created_at: :desc, id: :desc).first
      return if reaction.nil?

      Signal.new(
        source: :reaction_sent,
        occurred_at: reaction.created_at,
        target_customer_id: reaction.target_customer_id,
        metadata: { reaction_type: reaction.reaction_type }
      )
    rescue NameError, NoMethodError, ActiveRecord::StatementInvalid
      nil
    end

    def reaction_received_signal
      reaction = SingingProfileReaction.where(target_customer_id: @customer.id).order(created_at: :desc, id: :desc).first
      return if reaction.nil?

      Signal.new(
        source: :reaction_received,
        occurred_at: reaction.created_at,
        target_customer_id: reaction.customer_id,
        metadata: { reaction_type: reaction.reaction_type }
      )
    rescue NameError, NoMethodError, ActiveRecord::StatementInvalid
      nil
    end

    def challenge_progress_signals
      return unless Object.const_defined?(:SingingAiChallengeProgress)

      progress_records = [
        latest_challenge_progress,
        latest_incomplete_challenge_progress
      ].compact.uniq(&:id)

      progress_records.map { |progress| challenge_progress_signal(progress) }
    rescue NameError, NoMethodError, ActiveRecord::StatementInvalid
      nil
    end

    def latest_challenge_progress
      SingingAiChallengeProgress.where(customer: @customer).order(updated_at: :desc, id: :desc).first
    end

    def latest_incomplete_challenge_progress
      SingingAiChallengeProgress.where(customer: @customer, completed: false).order(updated_at: :desc, id: :desc).first
    end

    def challenge_progress_signal(progress)
      Signal.new(
        source: :challenge_progress,
        occurred_at: timestamp_for(progress, :updated_at, :created_at),
        target_customer_id: nil,
        metadata: {
          target_key: progress.target_key,
          completed: progress.completed?
        }
      )
    end

    def timestamp_for(record, *attributes)
      attributes.each do |attribute|
        next unless record.respond_to?(attribute)

        value = record.public_send(attribute)
        return value if value.present?
      end

      nil
    end

    def inactive
      Result.new(active: false, latest_signal: nil, signals: [])
    end
  end
end
