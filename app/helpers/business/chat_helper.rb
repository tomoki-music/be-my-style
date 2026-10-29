module Business
  # タイムライン(CommunityPost) / プロジェクトチャット(ProjectChat)の本文・添付表示。
  module ChatHelper
    DOCUMENT_LABELS = {
      "pdf" => "PDF",
      "doc" => "Word", "docx" => "Word",
      "xls" => "Excel", "xlsx" => "Excel",
      "ppt" => "PowerPoint", "pptx" => "PowerPoint"
    }.freeze

    # 書式なしで入力された本文の中から、リンクにする URL。全角文字や空白・引用符・<> で区切る。
    PLAIN_TEXT_URL_REGEX = %r{https?://[A-Za-z0-9\-._~:/?#\[\]@!$&*+,;=%]+}.freeze

    # 現在の投稿(plain)は本文をすべて文字として表示し、改行と URL のリンクだけを付ける。
    # 書式ボタンがあった時期の投稿(markdown)と機能追加前の投稿(legacy)は、投稿当時と同じ表示方式のまま描画する。
    def business_chat_body(record)
      return "" if record.body.blank?

      if record.content_format_plain?
        tag.div(business_chat_plain_text(record.body), class: "business-chat-plain")
      elsif record.content_format_markdown?
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

    # 文字はすべてエスケープしてから、URL だけを a 要素にする(貼り付けた HTML は文字のまま表示される)。
    def business_chat_plain_text(text)
      normalized = text.to_s.gsub(/\r\n?/, "\n")
      linked = safe_join(normalized.split(/(#{PLAIN_TEXT_URL_REGEX})/).map { |part|
        part.match?(/\A#{PLAIN_TEXT_URL_REGEX}\z/) ? link_to(part, part, target: "_blank", rel: "noopener noreferrer nofollow") : part
      })
      simple_format(linked, {}, sanitize: false)
    end

    def business_chat_file_path(attachment, thumbnail: false)
      business_chat_attachment_path(attachment.id, thumbnail ? { variant: "thumb" } : {})
    end

    def business_chat_document_label(attachment)
      DOCUMENT_LABELS.fetch(attachment.filename.extension_without_delimiter.to_s.downcase, "資料")
    end
  end
end
