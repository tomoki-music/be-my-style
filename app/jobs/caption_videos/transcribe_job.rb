module CaptionVideos
  class TranscribeJob < ApplicationJob
    queue_as :default

    MAX_RETRY_ATTEMPTS = 2
    RETRY_WAIT = 5.seconds

    # attempt: 一時的なAPI障害(タイムアウト/接続エラー)のみ限定的にリトライするためのカウンタ。
    def perform(caption_video_id, attempt = 0)
      video = CaptionVideo.find_by(id: caption_video_id)
      return if video.blank?
      # 冪等性: transcribing以外なら何もしない。二重実行・二重課金を防ぐ。
      return unless video.transcribing?
      return if video.transcribed_at.present?
      return unless video.extracted_audio.attached?

      Dir.mktmpdir(["caption_video_transcribe_#{video.id}_"], tmp_root) do |dir|
        audio_path = File.join(dir, "audio.mp3")
        download_attachment!(video.extracted_audio, audio_path)

        segments = CaptionVideos::TranscriptionClient.new.transcribe(
          audio_path: audio_path,
          language: video.transcript_language
        )

        captions = CaptionVideos::CaptionSegmenter.call(segments)
        persist_captions!(video, captions)
      end

      video.update!(status: "ready_for_edit", transcribed_at: Time.current, error_message: nil)
      video.extracted_audio.purge
    rescue CaptionVideos::TranscriptionClient::ConfigurationError => e
      # ConfigurationError/ResponseFormatError は RequestError のサブクラスのため、
      # 非リトライ対象のこれらを先に rescue し、リトライ対象(下のTimeoutError/RequestError)より
      # 優先して捕捉する。
      Rails.logger.error("[CaptionVideos::TranscribeJob] configuration error caption_video_id=#{caption_video_id} error=#{e.class}: #{e.message}")
      video&.mark_failed!("文字起こし機能が現在利用できません。しばらくしてからお試しください。")
    rescue CaptionVideos::TranscriptionClient::ResponseFormatError => e
      Rails.logger.error("[CaptionVideos::TranscribeJob] response format error caption_video_id=#{caption_video_id} error=#{e.class}: #{e.message}")
      video&.mark_failed!("文字起こし結果を取得できませんでした。もう一度お試しください。")
    rescue CaptionVideos::TranscriptionClient::TimeoutError, CaptionVideos::TranscriptionClient::RequestError => e
      Rails.logger.error("[CaptionVideos::TranscribeJob] transient error caption_video_id=#{caption_video_id} attempt=#{attempt} error=#{e.class}: #{e.message}")
      if attempt < MAX_RETRY_ATTEMPTS
        self.class.set(wait: RETRY_WAIT).perform_later(caption_video_id, attempt + 1)
      else
        video&.mark_failed!("文字起こしに失敗しました。時間をおいてもう一度お試しください。")
      end
    rescue StandardError => e
      Rails.logger.error("[CaptionVideos::TranscribeJob] unexpected error caption_video_id=#{caption_video_id} error=#{e.class}: #{e.message}")
      video&.mark_failed!("処理中に問題が発生しました。もう一度お試しください。")
    end

    private

    def persist_captions!(video, captions)
      ActiveRecord::Base.transaction do
        # 冪等性: 再実行で二重登録しないよう、既存テロップは一旦クリアしてから作り直す。
        video.video_captions.destroy_all
        captions.each_with_index do |caption, index|
          video.video_captions.create!(
            start_time: caption[:start_time],
            end_time: caption[:end_time],
            text: caption[:text],
            caption_type: "normal",
            position: "bottom_center",
            display_order: index
          )
        end
      end
    end

    def download_attachment!(attachment, path)
      File.open(path, "wb") do |file|
        attachment.download { |chunk| file.write(chunk) }
      end
    end

    def tmp_root
      path = ENV.fetch("CAPTION_VIDEO_TMP_ROOT", Rails.root.join("tmp", "caption_videos").to_s)
      FileUtils.mkdir_p(path)
      path
    end
  end
end
