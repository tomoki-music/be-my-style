module CaptionVideos
  class RenderJob < ApplicationJob
    queue_as :default

    def perform(caption_video_id)
      video = CaptionVideo.find_by(id: caption_video_id)
      return if video.blank?
      # 冪等性: 既にrendering中なら二重実行しない。
      return if video.rendering?
      return unless video.render_requestable?

      # 本番はAsyncAdapter(Pumaワーカー内実行)で専用ジョブキューが無いため、
      # 重い動画エンコードの同時実行数をグローバルに1件へ制限する(Recap Movie機能と同じ方針)。
      return if CaptionVideo.rendering.where.not(id: video.id).exists?

      video.mark_processing!("rendering")

      Dir.mktmpdir(["caption_video_render_#{video.id}_"], tmp_root) do |dir|
        input_path = File.join(dir, "source.mp4")
        download_attachment!(video.source_video, input_path)

        ass_path = File.join(dir, "captions.ass")
        ass_content = CaptionVideos::AssSubtitleGenerator.call(
          video.video_captions.ordered,
          width: video.width,
          height: video.height
        )
        File.write(ass_path, ass_content)

        output_path = File.join(dir, "rendered.mp4")
        CaptionVideos::VideoRenderer.new(
          input_path: input_path,
          ass_path: ass_path,
          output_path: output_path
        ).call

        video.rendered_video.attach(
          io: File.open(output_path),
          filename: output_filename(video),
          content_type: "video/mp4"
        )
      end

      video.mark_completed!
    rescue CaptionVideos::VideoRenderer::RenderError => e
      Rails.logger.error("[CaptionVideos::RenderJob] render failed caption_video_id=#{caption_video_id} error=#{e.class}: #{e.message}")
      video&.mark_failed!("動画の生成に失敗しました。もう一度お試しください。")
    rescue StandardError => e
      Rails.logger.error("[CaptionVideos::RenderJob] unexpected error caption_video_id=#{caption_video_id} error=#{e.class}: #{e.message}")
      video&.mark_failed!("処理中に問題が発生しました。もう一度お試しください。")
    end

    private

    def output_filename(video)
      base = video.title.to_s.parameterize.presence || "caption_video"
      "#{base}.mp4"
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
