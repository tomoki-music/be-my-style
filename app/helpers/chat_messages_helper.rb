module ChatMessagesHelper
  REPLY_EXCERPT_LENGTH = 60
  SEARCH_EXCERPT_LENGTH = 120

  def chat_markdown(chat_message)
    Rails.cache.fetch(
      ["chat_message_markdown", Chat::MarkdownRenderer::CACHE_VERSION, chat_message.cache_key_with_version],
      expires_in: 30.days
    ) { Chat::MarkdownRenderer.call(chat_message.content) }
  end

  # 返信元カード・返信ボタンのdata属性に載せる、安全なプレーンテキストの抜粋を返す。
  # Markdown記法を可能な範囲で除去し、改行はスペースへ変換、長すぎる場合は省略する。
  # 呼び出し側(Haml)で通常通りエスケープされる前提の「プレーンテキスト」を返すこと。
  # 引用プレビュー・引用カードでも同じ抜粋処理を再利用する(引用元本文をそのまま
  # Markdownレンダリングしないための、プレーンテキスト化の一元窓口)。
  def chat_reply_excerpt(chat_message)
    return attachment_or_stamp_label(chat_message) if chat_message.content.blank?

    plain_text_excerpt(chat_message.content, REPLY_EXCERPT_LENGTH).presence || attachment_or_stamp_label(chat_message)
  end

  # 検索結果カードの本文抜粋。プレーンテキスト化はchat_reply_excerptと同じロジックを再利用し、
  # 長さのみ検索結果に適した長さ(SEARCH_EXCERPT_LENGTH)にする。
  def chat_search_excerpt(chat_message)
    return attachment_or_stamp_label(chat_message) if chat_message.content.blank?

    plain_text_excerpt(chat_message.content, SEARCH_EXCERPT_LENGTH).presence || attachment_or_stamp_label(chat_message)
  end

  # 引用対象(chat_message)に画像添付があるかどうか。引用プレビュー・引用カードの
  # 文言分岐(「画像を引用」表示・サムネイル表示)に使う。
  def chat_quote_has_image?(chat_message)
    chat_message.attachments.attached? && chat_message.attachments.any?(&:image?)
  end

  # 引用ボタン・引用プレビューの見出しに使う「◯◯さんのメッセージを引用」/
  # 「◯◯さんの画像を引用」の文言を返す。
  def chat_quote_label(chat_message)
    name = chat_message.customer.name
    if chat_message.content.blank? && chat_quote_has_image?(chat_message)
      "#{name}さんの画像を引用"
    else
      "#{name}さんのメッセージを引用"
    end
  end

  # ピン一覧・メッセージ本体の解除ボタン表示可否(表示上のヒント)。
  # 実際の許可判定はPublic::ChatMessagesController#unpin_allowed?がサーバー側で
  # 再検証するため、ここでの結果はUI表示のみに使い、認可の最終判断には使わない。
  # DMの場合はroom閲覧が既に許可されている(=参加者である)前提でtrueを返す。
  def can_unpin_chat_message?(chat_message_pin, community)
    return false if chat_message_pin.blank?
    return true if chat_message_pin.pinned_by_customer_id == current_customer.id
    return true if current_customer.admin?
    return true if community.present? && current_customer.can_manage_community?(community)

    community.blank?
  end

  private

  def plain_text_excerpt(content, length)
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
    text.truncate(length)
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
