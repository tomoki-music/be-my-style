module MarkdownHelper
  # Redcarpet はチェックリスト記法を解釈せず「[ ] 項目」の文字のまま出すため、task_lists: true の
  # ときだけ記号に置き換える(入力欄 <input> は Sanitize で消えるので使わない)。
  TASK_LIST_ITEM_REGEX = %r{<li>(<p>)?\[([ xX])\] }.freeze

  # text_colors: true で `{color:red}文字{/color}` の文字色記法(MarkdownTextColors)を描画する。
  def markdown(text, text_colors: false, task_lists: false)
    return "" if text.blank?

    # 改行統一
    normalized = text.to_s.gsub(/\r\n?/, "\n")
    normalized = MarkdownTextColors.substitute(normalized) if text_colors

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
    html = MarkdownTextColors.restore(html) if text_colors
    html = render_task_list_items(html) if task_lists

    Sanitize.fragment(html, Sanitize::Config::RELAXED).html_safe
  end

  def render_task_list_items(html)
    html.gsub(TASK_LIST_ITEM_REGEX) do
      mark = Regexp.last_match(2) == " " ? "☐" : "☑"
      %(<li class="md-task-item">#{Regexp.last_match(1)}#{mark} )
    end
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