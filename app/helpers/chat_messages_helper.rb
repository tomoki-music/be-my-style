module ChatMessagesHelper
  def chat_markdown(chat_message)
    Rails.cache.fetch(
      ["chat_message_markdown", Chat::MarkdownRenderer::CACHE_VERSION, chat_message.cache_key_with_version],
      expires_in: 30.days
    ) { Chat::MarkdownRenderer.call(chat_message.content) }
  end
end
