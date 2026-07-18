module ChatMessagesHelper
  REPLY_EXCERPT_LENGTH = 60

  def chat_markdown(chat_message)
    Rails.cache.fetch(
      ["chat_message_markdown", Chat::MarkdownRenderer::CACHE_VERSION, chat_message.cache_key_with_version],
      expires_in: 30.days
    ) { Chat::MarkdownRenderer.call(chat_message.content) }
  end

  # 返信元カード・返信ボタンのdata属性に載せる、安全なプレーンテキストの抜粋を返す。
  # Markdown記法を可能な範囲で除去し、改行はスペースへ変換、長すぎる場合は省略する。
  # 呼び出し側(Haml)で通常通りエスケープされる前提の「プレーンテキスト」を返すこと。
  def chat_reply_excerpt(chat_message)
    return attachment_or_stamp_label(chat_message) if chat_message.content.blank?

    plain_text_excerpt(chat_message.content).presence || attachment_or_stamp_label(chat_message)
  end

  private

  def plain_text_excerpt(content)
    text = content.to_s.gsub(/```.*?```/m, " ")
    text = text.gsub(/`([^`]+)`/, '\1')
    text = text.gsub(/\[@([^\]]*)\]\(customer:\d+\)/, '@\1')
    text = text.gsub(/!\[([^\]]*)\]\([^)]*\)/) { Regexp.last_match(1).presence || "画像" }
    text = text.gsub(/\[([^\]]*)\]\([^)]*\)/, '\1')
    text = text.gsub(/^\#{1,6}\s*/, "")
    text = text.gsub(/^>\s?/, "")
    text = text.gsub(/^[-*+]\s+/, "")
    text = text.gsub(/^\d+\.\s+/, "")
    text = text.gsub(/[*_~]{1,3}/, "")
    text = text.gsub(/\r\n|\r|\n/, " ")
    text = text.squish
    text.truncate(REPLY_EXCERPT_LENGTH)
  end

  def attachment_or_stamp_label(chat_message)
    return chat_message.stamp_label if chat_message.stamped?
    return "" unless chat_message.attachments.attached?

    file = chat_message.attachments.first
    if file.image?
      "画像"
    elsif file.content_type == "application/pdf"
      "PDFファイル"
    elsif file.content_type.to_s.start_with?("audio/")
      "音声ファイル"
    elsif file.content_type.to_s.start_with?("video/")
      "動画ファイル"
    else
      "添付ファイル"
    end
  end
end
