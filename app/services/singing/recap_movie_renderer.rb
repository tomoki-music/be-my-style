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
      customer = @recap_movie.customer
      year     = @recap_movie.year
      stats    = yearly_diagnosis_stats(customer, year)

      {
        recapMovieId:    @recap_movie.id,
        customerId:      @recap_movie.customer_id,
        year:            year,
        theme:           "default",
        userName:        customer.name.to_s,
        diagnosisCount:  stats[:count],
        bestScore:       stats[:best_score],
        averageScore:    stats[:average_score],
        topGrowthMetric: stats[:top_growth_metric],
        voiceType:       stats[:voice_type]
      }
    end

    SCORE_GROWTH_LABELS = {
      overall_score:    "総合力",
      pitch_score:      "音程",
      rhythm_score:     "リズム",
      expression_score: "表現力"
    }.freeze

    def yearly_diagnosis_stats(customer, year)
      year_range = Time.zone.local(year).all_year

      diagnoses = customer.singing_diagnoses
        .completed
        .where(created_at: year_range)
        .order(:created_at, :id)
        .to_a

      scored = diagnoses.select { |d| d.overall_score.present? }

      {
        count:            diagnoses.size,
        best_score:       scored.map(&:overall_score).max,
        average_score:    scored.empty? ? nil : (scored.sum(&:overall_score) / scored.size.to_f).round,
        top_growth_metric: compute_top_growth_metric(diagnoses),
        voice_type:       compute_voice_type_label(scored.last)
      }
    end

    def compute_top_growth_metric(diagnoses)
      return nil if diagnoses.size < 2

      SCORE_GROWTH_LABELS.filter_map do |attr, label|
        values = diagnoses.filter_map { |d| d.public_send(attr) }
        next if values.size < 2

        [label, values.last.to_i - values.first.to_i]
      end.max_by { |_, delta| delta }&.first
    end

    def compute_voice_type_label(diagnosis)
      return nil unless diagnosis

      result = SingingDiagnoses::VoiceTypeAnalyzer.call(diagnosis)
      SingingDiagnoses::VoiceTypeAnalyzer::VOICE_TYPE_LABELS[result[:main_type]]
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
