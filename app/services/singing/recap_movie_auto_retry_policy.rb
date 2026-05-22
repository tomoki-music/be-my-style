module Singing
  class RecapMovieAutoRetryPolicy
    # エラーメッセージ/クラスがこのパターンに一致する場合のみ auto retry 対象とする
    RETRYABLE_PATTERNS = [
      /timeout/i,
      /temporary failure/i,
      /chrome/i,
      /chromium/i,
      /render process exited/i,
      /ffmpeg exited 1/i,
      /process exited/i,
      /connection reset/i,
      /econnreset/i,
      /socket hang up/i,
    ].freeze

    # これらのエラークラスは永続的失敗とみなし auto retry しない
    NON_RETRYABLE_CLASSES = %w[
      ActiveRecord::RecordInvalid
      ActiveRecord::RecordNotFound
      ActiveRecord::RecordNotUnique
      ArgumentError
      NameError
      TypeError
      NoMethodError
    ].freeze

    # 1回目: 5分後、2回目: 15分後、3回目以降: 30分後
    RETRY_INTERVALS = [5.minutes, 15.minutes, 30.minutes].freeze

    def self.auto_retryable?(failure)
      new(failure).auto_retryable?
    end

    def self.schedule_auto_retry_if_eligible!(failure)
      return unless new(failure).auto_retryable?

      failure.update!(
        auto_retry_status:  :scheduled,
        next_auto_retry_at: next_retry_at(0)
      )
    end

    def self.next_retry_at(attempts_count)
      delay = RETRY_INTERVALS[attempts_count] || RETRY_INTERVALS.last
      Time.current + delay
    end

    def initialize(failure)
      @failure = failure
    end

    def auto_retryable?
      return false if NON_RETRYABLE_CLASSES.include?(@failure.error_class.to_s)
      retryable_error_signature?
    end

    private

    def retryable_error_signature?
      sig = [@failure.error_class.to_s, @failure.error_message.to_s].join(" ")
      RETRYABLE_PATTERNS.any? { |pattern| sig.match?(pattern) }
    end
  end
end
