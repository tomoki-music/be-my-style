require "open3"
require "timeout"

module Singing
  class RecapMovieRenderer
    MAX_ERROR_LENGTH  = 1000
    RENDER_TIMEOUT_SEC = 150

    def initialize(recap_movie)
      @recap_movie = recap_movie
    end

    def call
      validate_paths!

      @recap_movie.update!(status: :processing, error_message: nil)
      Rails.logger.info("[RecapMovieRenderer] start movie_id=#{@recap_movie.id} year=#{@recap_movie.year}")

      Dir.mktmpdir(["recap_movie_", "_#{@recap_movie.id}"], tmp_root) do |dir|
        props_path  = File.join(dir, "props.json")
        output_path = File.join(dir, "recap_#{@recap_movie.year}.mp4")

        File.write(props_path, JSON.pretty_generate(props_payload))
        Rails.logger.info("[RecapMovieRenderer] props exported movie_id=#{@recap_movie.id} path=#{props_path}")

        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        stdout, stderr, status = Timeout.timeout(RENDER_TIMEOUT_SEC) do
          Rails.logger.info("[RecapMovieRenderer] render command start movie_id=#{@recap_movie.id} script=#{absolute_script_path} chdir=#{remotion_root}")
          Open3.capture3(
            render_env,
            "node",
            absolute_script_path,
            "--props", props_path,
            "--out",   output_path,
            chdir: remotion_root.to_s
          )
        end

        elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at).round(1)

        unless status.success?
          truncated_stderr = stderr.to_s.truncate(MAX_ERROR_LENGTH)
          Rails.logger.error("[RecapMovieRenderer] render command failed movie_id=#{@recap_movie.id} exit_status=#{status.exitstatus} elapsed=#{elapsed}s stderr=#{truncated_stderr}")
          fail_with!("render failed exit_status=#{status.exitstatus} stderr=#{truncated_stderr}")
          return false
        end

        Rails.logger.info("[RecapMovieRenderer] render command success movie_id=#{@recap_movie.id} elapsed=#{elapsed}s stdout=#{stdout.to_s.truncate(300)}")

        unless File.exist?(output_path) && File.size?(output_path)
          Rails.logger.error("[RecapMovieRenderer] render output missing or empty movie_id=#{@recap_movie.id} path=#{output_path}")
          fail_with!("render output missing or empty")
          return false
        end

        attach_video!(output_path)
        Rails.logger.info("[RecapMovieRenderer] attach success movie_id=#{@recap_movie.id}")

        @recap_movie.mark_completed!
        Rails.logger.info("[RecapMovieRenderer] completed movie_id=#{@recap_movie.id} elapsed_total=#{elapsed}s")
        true
      end
    rescue Timeout::Error
      Rails.logger.error("[RecapMovieRenderer] render timeout movie_id=#{@recap_movie.id} timeout=#{RENDER_TIMEOUT_SEC}s")
      fail_with!("render timeout (#{RENDER_TIMEOUT_SEC}s)")
      false
    rescue => e
      Rails.logger.error("[RecapMovieRenderer] unexpected error movie_id=#{@recap_movie.id} error=#{e.message.truncate(MAX_ERROR_LENGTH)}")
      fail_with!(e.message)
      false
    end

    private

    def validate_paths!
      unless Dir.exist?(remotion_root.to_s)
        raise "BEMYSTYLE_REEL_PATH not found: #{remotion_root} — set BEMYSTYLE_REEL_PATH env var"
      end

      unless File.exist?(absolute_script_path)
        raise "render script not found: #{absolute_script_path} — check RECAP_MOVIE_RENDER_SCRIPT or bemystyle-reel setup"
      end
    end

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
      Rails.logger.error("[RecapMovieRenderer] fail_with movie_id=#{@recap_movie.id} message=#{truncated}")
      @recap_movie.mark_failed!(truncated)
    end

    def render_env
      {}
    end

    def remotion_root
      @remotion_root ||= ENV.fetch("BEMYSTYLE_REEL_PATH", Rails.root.join("..", "bemystyle-reel").to_s)
    end

    def render_script_path
      ENV.fetch("RECAP_MOVIE_RENDER_SCRIPT", "scripts/render_recap_movie.js")
    end

    def absolute_script_path
      @absolute_script_path ||= File.expand_path(render_script_path, remotion_root)
    end

    def tmp_root
      path = ENV.fetch("RECAP_MOVIE_TMP_ROOT", Rails.root.join("tmp", "generated_recap_movies").to_s)
      FileUtils.mkdir_p(path)
      path
    end
  end
end
