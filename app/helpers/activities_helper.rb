module ActivitiesHelper
  def activity_markdown(text)
    markdown(text, text_colors: true, task_lists: true)
  end

  # 入力欄ツールバーのボタン(チャット欄と同じ並び)。[data-md-action, アイコン, ラベル, 説明]
  ACTIVITY_FORMAT_BUTTONS = [
    ["bold", "B", "太字", "選んだ文字を太字にする"],
    ["italic", "I", "斜体", "選んだ文字を斜体にする"],
    ["heading", "H", "見出し", "行を見出しにする"],
    ["strikethrough", "S", "取り消し線", "選んだ文字に取り消し線を引く"],
    ["quote", "\u201D", "引用", "選んだ行を引用にする"],
    ["unordered-list", "\u2022", "箇条書き", "選んだ行を箇条書きにする"],
    ["ordered-list", "1.", "番号付きリスト", "選んだ行を番号付きリストにする"],
    ["checklist", "\u2611", "チェックリスト", "選んだ行をチェックリストにする"],
    ["code", "</>", "コード", "選んだ文字をコードにする"],
    ["codeblock", "{ }", "コードブロック", "選んだ行をコードブロックにする"],
    ["link", "\u{1F517}", "リンク", "リンクを挿入する"],
    ["image", "\u{1F5BC}", "画像", "画像のURLを挿入する"],
    ["hr", "\u2015", "区切り線", "区切り線を挿入する"]
  ].freeze

  def activity_format_buttons
    ACTIVITY_FORMAT_BUTTONS
  end

  # 一覧カード等の短い抜粋用。装飾を外した文字だけを返す(HAML 側でエスケープされる)。
  def activity_plain_text(text)
    return "" if text.blank?

    Nokogiri::HTML::DocumentFragment.parse(activity_markdown(text)).text.squish
  end

  def activity_text_color_options
    MarkdownTextColors::COLORS
  end
end
