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

      if SingingGeneratedRecapMovie.processing.where.not(id: movie.id).exists?
        Rails.logger.warn(
          "[RecapMovieGenerationSafety] skipped movie_id=#{movie.id} because another movie is processing"
        )
        return
      end

      Singing::RecapMovieRenderer.new(movie).call
      reconcile(movie)
    rescue StandardError => e
      Rails.logger.error("[Singing::GenerateRecapMovieJob] error movie_id=#{movie_id}: #{e.message}")
      movie&.mark_failed!(e.message)
      reconcile(movie) if movie
    end

    private

    def reconcile(movie)
      Singing::RecapMovieRetryReconciliationService.call(movie.reload)
    rescue => e
      Rails.logger.error("[Singing::GenerateRecapMovieJob] reconciliation error movie_id=#{movie.id}: #{e.message}")
    end
  end
end
