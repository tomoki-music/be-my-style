module MarkdownHelper
  def markdown(text)
    return "" if text.blank?

    # 改行統一
    normalized = text.to_s.gsub(/\r\n?/, "\n")

    renderer = Redcarpet::Render::HTML.new(
      filter_html: true,
      hard_wrap: true  # ← これだけでOKにする
    )

    markdown = Redcarpet::Markdown.new(renderer,
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true
    )

    html = markdown.render(normalized)

    Sanitize.fragment(html, Sanitize::Config::RELAXED).html_safe
  end

  def placeholder_markdown_profile
    <<~TEXT
      # 🎤 自己紹介タイトル

      こんにちは！トモキです😊  
      音楽とコミュニティ運営が大好きです！

      ## 🔥 活動内容
      - バンドセッション開催
      - 音楽仲間づくり
      - Webアプリ開発（Rails / AWS）

      ## 🎸 好きな音楽
      - ONE OK ROCK
      - Official髭男dism
      - Mr.Children

      ## 💡 こんな人と繋がりたい
      音楽が好きな人！
      初心者も大歓迎✨

      ---

      ### ✏️ Markdownの使い方
      # 見出し1
      ## 見出し2
      ### 見出し3

      - リスト
      - リスト

      1. 番号リスト
      2. 番号リスト

      **太字**
      *斜体*

      [リンク](https://example.com)

      `コード`

      TEXT
  end
end