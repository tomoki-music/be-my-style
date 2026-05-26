module Singing
  class RecapMovieRequestService
    Result = Struct.new(
      :movie,
      :created,
      :reused,
      :queued,
      :status,
      :message,
      keyword_init: true
    )

    def self.call(customer, year:)
      new(customer, year: year).call
    end

    def initialize(customer, year:)
      @customer = customer
      @year     = year.to_i
    end

    def call
      movie = @customer.singing_generated_recap_movies.find_by(year: @year)

      if movie
        handle_existing(movie)
      else
        create_new
      end
    end

    private

    def handle_existing(movie)
      return reused_result(movie)     if movie.reusable?
      return pending_result(movie)    if movie.pending?
      return processing_result(movie) if movie.processing?

      # failed / expired / completed but expires_at in the past → reset
      reset_to_pending(movie)
    end

    def create_new
      source = build_source_json

      movie = @customer.singing_generated_recap_movies.create!(
        year:        @year,
        status:      :pending,
        source_json: source
      )

      Result.new(
        movie:   movie,
        created: true,
        reused:  false,
        queued:  false,
        status:  :created_pending,
        message: "新規 pending レコードを作成しました"
      )
    end

    def reset_to_pending(movie)
      source = build_source_json

      movie.update!(status: :pending, source_json: source, error_message: nil)

      Result.new(
        movie:   movie,
        created: false,
        reused:  false,
        queued:  false,
        status:  :reset_pending,
        message: "既存レコードを pending にリセットしました"
      )
    end

    def reused_result(movie)
      Result.new(
        movie:   movie,
        created: false,
        reused:  true,
        queued:  false,
        status:  :reused_completed,
        message: "完了済みの Recap Movie を再利用します"
      )
    end

    def pending_result(movie)
      Result.new(
        movie:   movie,
        created: false,
        reused:  true,
        queued:  false,
        status:  :already_pending,
        message: "既に pending 状態です"
      )
    end

    def processing_result(movie)
      Result.new(
        movie:   movie,
        created: false,
        reused:  true,
        queued:  false,
        status:  :already_processing,
        message: "既に processing 状態です"
      )
    end

    def build_source_json
      result = Singing::AchievementRecapMovieBuilder.call(@customer, year: @year)
      return nil if result.empty?

      Singing::AchievementRecapMovieSerializer.new(result).as_json
    end
  end
end
