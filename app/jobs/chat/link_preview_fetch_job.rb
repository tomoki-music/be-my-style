module Chat
  # ChatMessageLinkPreview 1件分の外部データ取得を行う。ApplicationJobの
  # retry_on/discard_onは使わず(プロジェクト全体で自動リトライは使わない方針)、
  # 単発実行・失敗時はstatus: failedとfailure_reasonを保存するだけに留める
  # (SingingDiagnoses::GenerateAiCommentJobと同じ設計方針)。
  #
  # queue_adapterは本番含めて:async(Pumaワーカー内の別スレッドで実行)であるため、
  # 外部通信のタイムアウトは短く保つ(Chat::LinkPreviews::YoutubeFetcher::DEFAULT_TIMEOUT = 3秒)。
  class LinkPreviewFetchJob < ApplicationJob
    queue_as :default

    def perform(chat_message_link_preview_id)
      preview = ChatMessageLinkPreview.find_by(id: chat_message_link_preview_id)
      return if preview.blank?
      return unless preview.pending?

      result = Chat::LinkPreviews::ProviderResolver.fetcher_for(preview.provider).call(preview.url)

      preview.update!(
        status: :fetched,
        title: result[:title],
        author_name: result[:author_name],
        thumbnail_url: result[:thumbnail_url],
        fetched_at: Time.current,
        failure_reason: nil
      )
    rescue StandardError => e
      Rails.logger.error("[Chat::LinkPreviewFetchJob] Failed: chat_message_link_preview_id=#{chat_message_link_preview_id} error=#{e.class}: #{e.message}")
      record_failure(preview, e)
    end

    private

    def record_failure(preview, error)
      return if preview.blank?

      preview.update!(status: :failed, failure_reason: "#{error.class}: #{error.message}".truncate(500))
    end
  end
end
