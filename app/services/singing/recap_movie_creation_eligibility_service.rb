module Singing
  class RecapMovieCreationEligibilityService
    Result = Struct.new(
      :eligible,
      :year,
      :completed_diagnoses_count,
      :required_diagnoses_count,
      :remaining_diagnoses_count,
      :period_start,
      :period_end,
      :period_label,
      :existing_movie,
      :existing_movie_status,
      :reason,
      :message,
      keyword_init: true
    ) do
      def eligible? = eligible
    end

    MIN_DIAGNOSES = 15

    def self.call(customer, year: nil)
      new(customer, year: year).call
    end

    def initialize(customer, year: nil)
      @customer       = customer
      @requested_year = year&.to_i
    end

    def call
      target_year = @requested_year || Time.current.year
      count = completed_diagnoses_count(target_year)

      return no_diagnosis_result(target_year)        if count == 0
      return not_enough_diagnoses_result(target_year, count) if count < MIN_DIAGNOSES

      movie = @customer.singing_generated_recap_movies.find_by(year: target_year)

      if movie
        result_for_existing(movie, target_year, count)
      else
        eligible_result(target_year, count, nil)
      end
    end

    private

    def completed_diagnoses_count(year)
      year_range = Time.zone.local(year).all_year
      @customer.singing_diagnoses.completed.where(created_at: year_range).count
    end

    def period_for(year)
      start  = Date.new(year, 1, 1)
      finish = Date.new(year, 12, 31)
      label  = "#{year}年1月1日〜#{year}年12月31日"
      [start, finish, label]
    end

    def result_for_existing(movie, year, count)
      case movie.status
      when "pending"
        ineligible_result(year, count, movie, :already_pending,
          "#{year}年のRecap Movieは現在生成待ちです。しばらくお待ちください。")
      when "processing"
        ineligible_result(year, count, movie, :already_processing,
          "#{year}年のRecap Movieは現在作成中です。数分後にご確認ください。")
      when "completed"
        if movie.reusable?
          ineligible_result(year, count, movie, :already_completed,
            "#{year}年のRecap Movieはすでに作成済みです。")
        else
          eligible_result(year, count, movie)
        end
      when "failed"
        eligible_result(year, count, movie, reason: :retry_failed,
          message: "#{year}年のRecap Movieの生成に失敗しました。再生成をリクエストできます。")
      when "expired"
        eligible_result(year, count, movie, reason: :retry_expired,
          message: "#{year}年のRecap Movieの保存期限が切れています。再生成できます。")
      else
        eligible_result(year, count, movie)
      end
    end

    def eligible_result(year, count, movie, reason: :eligible, message: nil)
      start, finish, label = period_for(year)
      msg = message || "条件を満たしています。#{year}年のRecap Movieを作成できます。"
      Result.new(
        eligible:                  true,
        year:                      year,
        completed_diagnoses_count: count,
        required_diagnoses_count:  MIN_DIAGNOSES,
        remaining_diagnoses_count: 0,
        period_start:              start,
        period_end:                finish,
        period_label:              label,
        existing_movie:            movie,
        existing_movie_status:     movie&.status,
        reason:                    reason,
        message:                   msg
      )
    end

    def ineligible_result(year, count, movie, reason, message)
      start, finish, label = period_for(year)
      Result.new(
        eligible:                  false,
        year:                      year,
        completed_diagnoses_count: count,
        required_diagnoses_count:  MIN_DIAGNOSES,
        remaining_diagnoses_count: 0,
        period_start:              start,
        period_end:                finish,
        period_label:              label,
        existing_movie:            movie,
        existing_movie_status:     movie&.status,
        reason:                    reason,
        message:                   message
      )
    end

    def not_enough_diagnoses_result(year, count)
      start, finish, label = period_for(year)
      remaining = MIN_DIAGNOSES - count
      Result.new(
        eligible:                  false,
        year:                      year,
        completed_diagnoses_count: count,
        required_diagnoses_count:  MIN_DIAGNOSES,
        remaining_diagnoses_count: remaining,
        period_start:              start,
        period_end:                finish,
        period_label:              label,
        existing_movie:            nil,
        existing_movie_status:     nil,
        reason:                    :not_enough_diagnoses,
        message:                   "あと#{remaining}件の診断を完了するとRecap Movieを作成できます。（現在#{count}件 / 必要#{MIN_DIAGNOSES}件）"
      )
    end

    def no_diagnosis_result(year)
      start, finish, label = period_for(year)
      Result.new(
        eligible:                  false,
        year:                      year,
        completed_diagnoses_count: 0,
        required_diagnoses_count:  MIN_DIAGNOSES,
        remaining_diagnoses_count: MIN_DIAGNOSES,
        period_start:              start,
        period_end:                finish,
        period_label:              label,
        existing_movie:            nil,
        existing_movie_status:     nil,
        reason:                    :no_diagnosis,
        message:                   "歌声診断を完了すると、Recap Movieを作成できるようになります。（必要#{MIN_DIAGNOSES}件）"
      )
    end
  end
end
