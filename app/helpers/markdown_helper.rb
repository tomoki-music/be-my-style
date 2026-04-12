# app/helpers/markdown_helper.rb
module MarkdownHelper
  def markdown(text)
    renderer = Redcarpet::Render::HTML.new(
      filter_html: true,
      hard_wrap: true
    )

    markdown = Redcarpet::Markdown.new(renderer,
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true
    )

    html = markdown.render(text || "")

    # サニタイズ（超重要）
    Sanitize.fragment(html, Sanitize::Config::RELAXED).html_safe
  end
end