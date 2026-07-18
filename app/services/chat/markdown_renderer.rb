module Chat
  class MarkdownRenderer
    # レンダリングロジックを変更したらここを上げてキャッシュ(ChatMessagesHelper)を無効化する
    CACHE_VERSION = "v2".freeze

    # ChatMessage#content には現状アプリ側の文字数上限が無い(DBはtext型)ため、
    # 極端に長い入力によるRouge/Sanitizeの処理負荷を抑える目的でレンダリング時のみ
    # 上限を設ける(保存内容そのものは変更しない。表示上末尾が切り詰められるだけ)。
    # プレビューAPIも同じ上限をこの一箇所で共有する。
    MAX_LENGTH = 20_000

    TASK_ITEM_REGEX = /\A(<p>)?\[([ xX])\]\s+/.freeze
    EMOJI_SHORTCODE_REGEX = /:([a-z0-9_+\-]+):/.freeze
    CODE_SEGMENT_REGEX = /(```.*?```|`[^`\n]*`)/m.freeze
    # `[@表示名](customer:123)` 記法のメンションを検出する。
    # 注: Redcarpet::Render::HTMLはRuby側にlinkメソッドの実体を持たないため、
    # コールバックをoverrideしてsuperで通常リンク処理へ委譲することができない
    # (defすると全リンクがこのコールバック経由になり、既存のMarkdownリンク挙動を壊す)。
    # そのため絵文字置換と同じ「生テキストの前処理」方式を採る: コード区間を除外して
    # プレースホルダに置換 → Markdownレンダリング → プレースホルダを最終HTMLへ復元。
    MENTION_REGEX = /\[@([^\]\n]*)\]\(customer:(\d+)\)/.freeze
    MENTION_TOKEN_REGEX = /\x02MENTION(\d+)\x03/.freeze

    ELEMENTS = %w[
      p br strong em del s
      h1 h2 h3
      ul ol li
      blockquote hr
      code pre span
      a img
      table thead tbody tr th td
      input
    ].freeze

    ATTRIBUTES = {
      "a"     => %w[href title rel target],
      "img"   => %w[src alt title],
      "pre"   => %w[class],
      "code"  => %w[class],
      "span"  => %w[class data-customer-id],
      "input" => %w[type checked disabled],
      "th"    => %w[align],
      "td"    => %w[align]
    }.freeze

    PROTOCOLS = {
      "a"   => { "href" => %w[http https mailto] },
      "img" => { "src"  => %w[http https] }
    }.freeze

    def self.call(text)
      new(text).render
    end

    def initialize(text)
      @text = text.to_s.first(MAX_LENGTH).gsub(/\r\n?/, "\n")
    end

    def render
      return "".html_safe if @text.blank?

      mentions = []
      text_with_placeholders = substitute_mentions(@text, mentions)
      html = markdown_engine.render(substitute_emoji(text_with_placeholders))
      html = restore_mentions(html, mentions)
      Sanitize.fragment(
        html,
        elements: ELEMENTS,
        attributes: ATTRIBUTES,
        protocols: PROTOCOLS
      ).html_safe
    end

    private

    # `[@表示名](customer:123)` をMarkdownパース前に一意なプレースホルダへ置き換える。
    # コードブロック/インラインコード内は対象外(絵文字置換と同じCODE_SEGMENT_REGEXで判定)。
    # 表示名はここで確定的にHTMLエスケープするため、Redcarpetのインライン処理(強調記法等)や
    # Sanitizeの結果に依存せずXSSを防げる。
    def substitute_mentions(text, mentions)
      text.split(CODE_SEGMENT_REGEX).each_with_index.map do |segment, index|
        next segment if index.odd?

        segment.gsub(MENTION_REGEX) do
          name = Regexp.last_match(1)
          customer_id = Regexp.last_match(2)
          mentions << %(<span class="chat-mention" data-customer-id="#{customer_id}">@#{CGI.escapeHTML(name)}</span>)
          "\x02MENTION#{mentions.size - 1}\x03"
        end
      end.join
    end

    def restore_mentions(html, mentions)
      html.gsub(MENTION_TOKEN_REGEX) { mentions[Regexp.last_match(1).to_i] || Regexp.last_match(0) }
    end

    # コードスパン/フェンスコードブロックの中身は絵文字変換の対象外にする。
    # Redcarpetのnormal_textコールバックはautolink有効時にコロンの周辺でテキストが
    # 分断されて呼ばれるため、コールバックフックではなく生Markdownテキストの
    # 前処理として一括置換する(コードセグメントだけ split で退避する)。
    def substitute_emoji(text)
      text.split(CODE_SEGMENT_REGEX).each_with_index.map do |segment, index|
        next segment if index.odd? # 奇数インデックスはCODE_SEGMENT_REGEXの捕捉=コード側

        segment.gsub(EMOJI_SHORTCODE_REGEX) { Emoji.find_by_alias(Regexp.last_match(1))&.raw || Regexp.last_match(0) }
      end.join
    end

    def markdown_engine
      Redcarpet::Markdown.new(
        HtmlRenderer.new(
          filter_html: true, # ユーザーが打った生<script>等はここでエスケープ・除去される(第一防壁)
          hard_wrap: true,
          safe_links_only: true,
          link_attributes: { rel: "noopener noreferrer", target: "_blank" }
        ),
        autolink: true,
        tables: true,
        fenced_code_blocks: true,
        strikethrough: true,
        no_intra_emphasis: true
      )
    end

    class HtmlRenderer < Redcarpet::Render::HTML
      # チェックリスト: `- [ ] foo` / `- [x] foo`
      # tight list -> content="[ ] foo\n" / loose list -> content="<p>[ ] foo</p>\n"(実測検証済み)
      def list_item(content, list_type)
        match = content.match(TASK_ITEM_REGEX)
        return "<li>#{content}</li>\n" unless match

        checked = match[2].casecmp("x").zero? ? " checked" : ""
        rest = content.sub(TASK_ITEM_REGEX, "")
        %(<li class="task-list-item">#{match[1]}<input type="checkbox" disabled#{checked}> #{rest}</li>\n)
      end

      # フェンスコードブロック: Rougeでサーバーサイドハイライト(クライアントJS不要)
      def block_code(code, language)
        lexer = Rouge::Lexer.find_fancy(language) || Rouge::Lexers::PlainText
        highlighted = Rouge::Formatters::HTML.new.format(lexer.lex(code))
        lang_class = language.present? ? " language-#{language.to_s.downcase.gsub(/[^a-z0-9_-]/, '')}" : ""
        %(<pre class="highlight#{lang_class}"><code>#{highlighted}</code></pre>\n)
      end
    end
  end
end
