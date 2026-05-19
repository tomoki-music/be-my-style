module Singing
  class GenerateRecapMovieJob < ApplicationJob
    queue_as :default

    def perform(movie_id)
      movie = SingingGeneratedRecapMovie.find_by(id: movie_id)

      unless movie
        Rails.logger.warn("[Singing::GenerateRecapMovieJob] movie not found: #{movie_id}")
        return
      end

      return unless movie.pending?

      Singing::RecapMovieRenderer.new(movie).call
    rescue StandardError => e
      Rails.logger.error("[Singing::GenerateRecapMovieJob] error movie_id=#{movie_id}: #{e.message}")
      movie&.mark_failed!(e.message)
    end
  end
end
