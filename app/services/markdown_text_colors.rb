# Markdown 本文中の文字色記法 `{color:red}文字{/color}` を扱う。
#
# Redcarpet は filter_html: true で生 HTML を無効化しているため、色は独自記法で受け取り、
# 許可した色名だけを class 付きの span に変換する(色の値・style 属性は利用者から受け取らない)。
# Chat::MarkdownRenderer のメンションと同じく、Markdown 変換前にプレースホルダへ置き換え、
# 変換後に span へ戻す。コード区間と改行をまたぐ記法は対象外(そのまま文字として表示)。
module MarkdownTextColors
  COLORS = {
    "red" => "赤",
    "blue" => "青",
    "green" => "緑",
    "orange" => "オレンジ",
    "purple" => "紫"
  }.freeze

  CSS_CLASS_PREFIX = "md-text-color--".freeze
  MARKER_REGEX = /\{color:(#{COLORS.keys.join('|')})\}([^\n]*?)\{\/color\}/.freeze
  CODE_SEGMENT_REGEX = /(```.*?```|`[^`\n]*`)/m.freeze
  # プレースホルダは「_」等の Markdown 記号を含めない(強調として解釈されるため)。
  # 閉じ側を「<」で始めるのは、直前の URL 自動リンクを「<」で終わらせるため
  # (Redcarpet はタグでない「<」を &lt; として出力する)。
  OPEN_TOKEN_REGEX = /\x02MDCOLOR(#{COLORS.keys.join('|')})\x03/.freeze
  CLOSE_TOKEN = "<\x02MDCOLOREND\x03".freeze
  RENDERED_CLOSE_TOKEN = "&lt;\x02MDCOLOREND\x03".freeze
  LEFTOVER_TOKEN_REGEX = /(?:&lt;|<)?(?:\x02|%02)MDCOLOR[a-z]*(?:\x03|%03)/.freeze

  module_function

  # Markdown 変換前のテキストを受け取り、記法をプレースホルダに置き換える。
  def substitute(text)
    text.split(CODE_SEGMENT_REGEX).each_with_index.map do |segment, index|
      next segment if index.odd?

      segment.gsub(MARKER_REGEX) do
        "\x02MDCOLOR#{Regexp.last_match(1)}\x03#{Regexp.last_match(2)}#{CLOSE_TOKEN}"
      end
    end.join
  end

  # Markdown 変換後の HTML のプレースホルダを span に戻す。リンク先 URL 等に紛れ込んで
  # 戻せなかったプレースホルダは取り除く(タグの入れ子崩れは後段の Sanitize が整える)。
  def restore(html)
    html
      .gsub(OPEN_TOKEN_REGEX) { %(<span class="md-text-color #{CSS_CLASS_PREFIX}#{Regexp.last_match(1)}">) }
      .gsub(RENDERED_CLOSE_TOKEN, "</span>")
      .gsub(LEFTOVER_TOKEN_REGEX, "")
  end

end
