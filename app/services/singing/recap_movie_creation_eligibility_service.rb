module Singing
  class RecapMovieCreationEligibilityService
    Result = Struct.new(
      :eligible,
      :year,
      :completed_diagnoses_count,
      :existing_movie,
      :existing_movie_status,
      :reason,
      :message,
      keyword_init: true
    ) do
      def eligible? = eligible
    end

    MIN_DIAGNOSES = 1

    def self.call(customer, year: nil)
      new(customer, year: year).call
    end

    def initialize(customer, year: nil)
      @customer      = customer
      @requested_year = year&.to_i
    end

    def call
      target_year = resolve_year
      return no_diagnosis_result if target_year.nil?

      count = completed_diagnoses_count(target_year)
      return no_diagnosis_result if count < MIN_DIAGNOSES

      movie = @customer.singing_generated_recap_movies.find_by(year: target_year)

      if movie
        result_for_existing(movie, target_year, count)
      else
        eligible_result(target_year, count, nil)
      end
    end

    private

    def resolve_year
      return @requested_year if @requested_year

      current_year = Time.current.year
      return current_year if completed_diagnoses_count(current_year) >= MIN_DIAGNOSES

      # 過去の診断がある最新年を探す
      past_cutoff = Time.zone.local(current_year).beginning_of_year
      latest_past = @customer.singing_diagnoses
        .completed
        .where(created_at: ...past_cutoff)
        .maximum(:created_at)

      latest_past&.year
    end

    def completed_diagnoses_count(year)
      year_range = Time.zone.local(year).all_year
      @customer.singing_diagnoses.completed.where(created_at: year_range).count
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
      msg = message || "#{year}年のRecap Movieを作成できます。（診断 #{count} 件）"
      Result.new(
        eligible:                  true,
        year:                      year,
        completed_diagnoses_count: count,
        existing_movie:            movie,
        existing_movie_status:     movie&.status,
        reason:                    reason,
        message:                   msg
      )
    end

    def ineligible_result(year, count, movie, reason, message)
      Result.new(
        eligible:                  false,
        year:                      year,
        completed_diagnoses_count: count,
        existing_movie:            movie,
        existing_movie_status:     movie&.status,
        reason:                    reason,
        message:                   message
      )
    end

    def no_diagnosis_result
      Result.new(
        eligible:                  false,
        year:                      nil,
        completed_diagnoses_count: 0,
        existing_movie:            nil,
        existing_movie_status:     nil,
        reason:                    :no_diagnosis,
        message:                   "歌声診断を完了すると、Recap Movieを作成できるようになります。"
      )
    end
  end
end
