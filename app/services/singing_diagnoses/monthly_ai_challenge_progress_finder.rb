module SingingDiagnoses
  class MonthlyAiChallengeProgressFinder
    def initialize(customer, challenge:, reference_time: Time.current)
      @customer = customer
      @challenge = challenge
      @reference_time = reference_time
    end

    def find_or_initialize
      scope.find_or_initialize_by(progress_key)
    end

    def find_or_create!
      scope.find_or_create_by!(progress_key)
    end

    def challenge_month
      reference_time.to_date.beginning_of_month
    end

    def target_key
      challenge[:target_key].to_s
    end

    private

    attr_reader :customer, :challenge, :reference_time

    def scope
      customer.singing_ai_challenge_progresses
    end

    def progress_key
      {
        challenge_month: challenge_month,
        target_key: target_key
      }
    end
  end
end
