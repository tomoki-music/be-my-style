require "open3"

module Singing
  class RecapMovieRenderer
    MAX_ERROR_LENGTH = 500

    def initialize(recap_movie)
      @recap_movie = recap_movie
    end

    def call
      @recap_movie.update!(status: :processing, error_message: nil)

      Dir.mktmpdir(["recap_movie_", "_#{@recap_movie.id}"], tmp_root) do |dir|
        props_path  = File.join(dir, "props.json")
        output_path = File.join(dir, "recap_#{@recap_movie.year}.mp4")

        File.write(props_path, JSON.pretty_generate(props_payload))

        stdout, stderr, status = Open3.capture3(
          render_env,
          "node",
          render_script_path,
          "--props", props_path,
          "--out",   output_path,
          chdir: remotion_root.to_s
        )

        Rails.logger.info("[RecapMovieRenderer] movie_id=#{@recap_movie.id} stdout=#{stdout.truncate(400)}")

        unless status.success?
          fail_with!("render failed exit_status=#{status.exitstatus} stderr=#{stderr.truncate(400)}")
          return false
        end

        unless File.exist?(output_path) && File.size?(output_path)
          fail_with!("render output missing or empty")
          return false
        end

        attach_video!(output_path)
        @recap_movie.mark_completed!
        true
      end
    rescue => e
      fail_with!(e.message)
      false
    end

    private

    def props_payload
      {
        recapMovieId: @recap_movie.id,
        customerId:   @recap_movie.customer_id,
        year:         @recap_movie.year,
        theme:        "default"
      }
    end

    def attach_video!(path)
      @recap_movie.video_file.attach(
        io:           File.open(path),
        filename:     "recap_#{@recap_movie.year}.mp4",
        content_type: "video/mp4"
      )
    end

    def fail_with!(message)
      truncated = message.to_s.truncate(MAX_ERROR_LENGTH)
      Rails.logger.error("[RecapMovieRenderer] movie_id=#{@recap_movie.id} error=#{truncated}")
      @recap_movie.mark_failed!(truncated)
    end

    def render_env
      {}
    end

    def remotion_root
      ENV.fetch("BEMYSTYLE_REEL_PATH", Rails.root.join("..", "bemystyle-reel").to_s)
    end

    def render_script_path
      ENV.fetch("RECAP_MOVIE_RENDER_SCRIPT", "scripts/render_recap_movie.js")
    end

    def tmp_root
      path = ENV.fetch("RECAP_MOVIE_TMP_ROOT", Rails.root.join("tmp", "generated_recap_movies").to_s)
      FileUtils.mkdir_p(path)
      path
    end
  end
end
