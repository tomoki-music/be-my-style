module CaptionVideos
  class ExtractAudioJob < ApplicationJob
    queue_as :default

    class IngestValidationError < StandardError; end

    def perform(caption_video_id)
      video = CaptionVideo.find_by(id: caption_video_id)
      return if video.blank?
      # 冪等性: uploaded以外(既に処理が進んでいる/完了している)なら何もしない。
      return unless video.uploaded?

      video.mark_processing!("extracting_audio")

      Dir.mktmpdir(["caption_video_#{video.id}_"], tmp_root) do |dir|
        input_path = File.join(dir, "source#{video.source_video_local_extension}")
        download_attachment!(video.source_video, input_path)

        probe = CaptionVideos::VideoProbe.new(input_path).call
        validate_probe!(probe)

        video.update!(
          duration: probe.duration,
          width: probe.width,
          height: probe.height,
          aspect_ratio: aspect_ratio_label(probe.width, probe.height)
        )

        audio_path = File.join(dir, "audio.mp3")
        CaptionVideos::AudioExtractor.new(input_path: input_path, output_path: audio_path).call

        video.extracted_audio.attach(
          io: File.open(audio_path),
          filename: "audio.mp3",
          content_type: "audio/mpeg"
        )
        video.update!(status: "transcribing", audio_extracted_at: Time.current)
      end

      CaptionVideos::TranscribeJob.perform_later(video.id)
    rescue IngestValidationError => e
      Rails.logger.error("[CaptionVideos::ExtractAudioJob] validation failed caption_video_id=#{caption_video_id} error=#{e.class}: #{e.message}")
      video&.mark_failed!(e.message)
    rescue CaptionVideos::VideoProbe::ProbeError => e
      # ProbeErrorのmessageにはffprobeの内部stderr等が含まれる場合があるため、
      # ユーザーへは汎用メッセージのみ返す(詳細はログにのみ残す)。
      Rails.logger.error("[CaptionVideos::ExtractAudioJob] probe failed caption_video_id=#{caption_video_id} error=#{e.class}: #{e.message}")
      video&.mark_failed!("動画ファイルを読み込めませんでした。ファイルが破損していないか確認し、対応形式(MP4/MOV)でアップロードしてください。")
    rescue CaptionVideos::AudioExtractor::ExtractionError => e
      Rails.logger.error("[CaptionVideos::ExtractAudioJob] extraction failed caption_video_id=#{caption_video_id} error=#{e.class}: #{e.message}")
      video&.mark_failed!("音声の準備に失敗しました。動画ファイルを確認してもう一度お試しください。")
    rescue StandardError => e
      Rails.logger.error("[CaptionVideos::ExtractAudioJob] unexpected error caption_video_id=#{caption_video_id} error=#{e.class}: #{e.message}")
      video&.mark_failed!("処理中に問題が発生しました。もう一度お試しください。")
    end

    private

    def download_attachment!(attachment, path)
      File.open(path, "wb") do |file|
        attachment.download { |chunk| file.write(chunk) }
      end
    end

    def validate_probe!(probe)
      if probe.duration.blank? || probe.duration <= 0
        raise IngestValidationError, "動画の長さを取得できませんでした。動画ファイルを確認してください。"
      end

      if probe.duration > CaptionVideo::MAX_DURATION_SECONDS
        raise IngestValidationError, "動画は30分以内にしてください。"
      end

      unless probe.format_name.to_s.split(",").any? { |f| CaptionVideos::VideoProbe::ALLOWED_FORMAT_NAMES.include?(f) }
        raise IngestValidationError, "MP4またはMOV形式の動画のみ対応しています。"
      end

      unless probe.has_audio_stream
        raise IngestValidationError, "この動画から音声を確認できませんでした。音声を含む動画をアップロードしてください。"
      end
    end

    def aspect_ratio_label(width, height)
      return nil if width.blank? || height.blank? || width.to_i.zero? || height.to_i.zero?

      gcd = width.to_i.gcd(height.to_i)
      "#{width.to_i / gcd}:#{height.to_i / gcd}"
    end

    def tmp_root
      path = ENV.fetch("CAPTION_VIDEO_TMP_ROOT", Rails.root.join("tmp", "caption_videos").to_s)
      FileUtils.mkdir_p(path)
      path
    end
  end
end
