module Business
  # タイムライン(CommunityPost) / プロジェクトチャット(ProjectChat)の本文・添付表示。
  module ChatHelper
    DOCUMENT_LABELS = {
      "pdf" => "PDF",
      "doc" => "Word", "docx" => "Word",
      "xls" => "Excel", "xlsx" => "Excel",
      "ppt" => "PowerPoint", "pptx" => "PowerPoint"
    }.freeze

    # 新しい投稿は送信時プレビューと同じ Chat::MarkdownRenderer で描画する。
    # 機能追加前の投稿(legacy)は、投稿当時と同じ表示方式のまま描画する。
    def business_chat_body(record)
      return "" if record.body.blank?

      if record.content_format_markdown?
        html = Rails.cache.fetch(
          ["business_chat_markdown", Chat::MarkdownRenderer::CACHE_VERSION, record.cache_key_with_version],
          expires_in: 30.days
        ) { Chat::MarkdownRenderer.call(record.body) }
        tag.div(html, class: "markdown-body business-chat-markdown")
      elsif record.is_a?(CommunityPost)
        tag.div(markdown(record.body), class: "markdown-body")
      else
        simple_format(record.body)
      end
    end

    def business_chat_file_path(attachment, thumbnail: false)
      business_chat_attachment_path(attachment.id, thumbnail ? { variant: "thumb" } : {})
    end

    def business_chat_document_label(attachment)
      DOCUMENT_LABELS.fetch(attachment.filename.extension_without_delimiter.to_s.downcase, "資料")
    end
  end
end
