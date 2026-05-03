module Singing::UsersHelper
  SINGING_MARKDOWN_TAGS = %w[
    a p br strong em ul ol li h1 h2 h3 blockquote code pre hr
  ].freeze

  SINGING_MARKDOWN_ATTRIBUTES = {
    "a" => %w[href title rel]
  }.freeze

  SINGING_MARKDOWN_PROTOCOLS = {
    "a" => {
      "href" => ["http", "https", "mailto"]
    }
  }.freeze

  def singing_markdown(text)
    return "" if text.blank?

    renderer = Redcarpet::Render::HTML.new(
      filter_html: true,
      hard_wrap: true,
      no_images: true,
      safe_links_only: true,
      link_attributes: { rel: "noopener noreferrer" }
    )

    normalized = text.to_s.gsub(/\r\n?/, "\n")
    normalized.gsub!(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/im, "")
    normalized.gsub!(/javascript:/i, "")

    html = Redcarpet::Markdown.new(
      renderer,
      autolink: true,
      strikethrough: true
    ).render(normalized)

    Sanitize.fragment(
      html,
      elements: SINGING_MARKDOWN_TAGS,
      attributes: SINGING_MARKDOWN_ATTRIBUTES,
      protocols: SINGING_MARKDOWN_PROTOCOLS
    ).html_safe
  end
end
