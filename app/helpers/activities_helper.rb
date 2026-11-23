module ActivitiesHelper
  def activity_markdown(text)
    markdown(text, text_colors: true)
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
