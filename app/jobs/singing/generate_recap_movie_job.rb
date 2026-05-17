module Singing
  class GenerateRecapMovieJob < ApplicationJob
    queue_as :default

    RENDERER_NOT_IMPLEMENTED_MESSAGE = "Renderer is not implemented."

    def perform(movie_id)
      movie = SingingGeneratedRecapMovie.find_by(id: movie_id)

      unless movie
        Rails.logger.warn("[Singing::GenerateRecapMovieJob] movie not found: #{movie_id}")
        return
      end

      return unless movie.pending?

      movie.mark_processing!

      # TODO: Remotion でmp4をレンダリングし S3 にアップロードする
      # Singing::RecapMovieRenderer.call(movie)
      # movie.mark_completed!

      movie.mark_failed!(RENDERER_NOT_IMPLEMENTED_MESSAGE)
    rescue StandardError => e
      Rails.logger.error("[Singing::GenerateRecapMovieJob] error movie_id=#{movie_id}: #{e.message}")
      movie&.mark_failed!(e.message)
    end
  end
end
