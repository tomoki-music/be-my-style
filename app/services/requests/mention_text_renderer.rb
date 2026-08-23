module Requests
  # イベントリクエスト本文を安全な表示用HTMLへ変換する。
  #
  # Markdownレンダリング自体はMarkdownHelper#markdown(プロフィール紹介文・コミュニティ紹介文等、
  # 既存の自由記述Markdown欄)と同じRedcarpet設定・Sanitize::Config::RELAXEDを再利用し、
  # アプリ内でのMarkdown表示の見た目・許可タグを揃える。
  #
  # メンション記法`[@表示名](customer:ID)`との共存は、Chat::MarkdownRendererと同じ
  # 「Markdownパース前に一意なプレースホルダへ退避し、レンダリング後に復元する」方式を採る
  # (退避しないと、メンション記法自体がMarkdownのリンク記法`[text](url)`と衝突し、
  # `<a href="customer:ID">`として展開されてしまうため)。
  #
  # customer_idがvalid_customer_ids(=現在のイベント参加者)に含まれない場合はメンション化せず、
  # エスケープ済みの通常テキスト(`@表示名`)としてそのまま表示する(Chat::MarkdownRendererと異なり
  # ここだけ有効性チェックが入るのは、本文の改ざん・イベント参加状態の変化(離脱等)があっても、
  # 通知対象から除外することと表示上の扱いを一致させるための既存仕様を維持するため)。
  # 表示名はここで確定的にCGI.escapeHTMLするため、Redcarpetのインライン処理や
  # Sanitizeの結果に依存せずXSSを防げる。
  class MentionTextRenderer
    MENTION_REGEX = Chat::MarkdownRenderer::MENTION_REGEX
    ALL_TOKEN_REGEX = /\[@ALL\]\(customer:all\)/.freeze
    MENTION_TOKEN_REGEX = /\x02MENTION(\d+)\x03/.freeze

    # requests.request はDB上はtext型で文字数上限が無いため、極端に長い入力による
    # Redcarpet/Sanitizeの処理負荷を抑える目的でレンダリング時のみ上限を設ける
    # (Chat::MarkdownRenderer::MAX_LENGTHと同じ考え方。保存内容自体は変更しない)。
    MAX_LENGTH = 20_000

    # Sanitize::Config::RELAXEDはmentionが使うdata-customer-id(data-*属性)を許可しないため、
    # spanのみ既存の許可属性(class等)に追加する形でマージする。
    SANITIZE_CONFIG = Sanitize::Config.merge(
      Sanitize::Config::RELAXED,
      attributes: { "span" => Sanitize::Config::RELAXED[:attributes][:all].to_a + %w[data-customer-id] }
    )

    def self.call(text, valid_customer_ids:)
      new(text, valid_customer_ids).render
    end

    def initialize(text, valid_customer_ids)
      @text = text.to_s.first(MAX_LENGTH).gsub(/\r\n?/, "\n")
      @valid_customer_ids = valid_customer_ids.map(&:to_i).to_set
    end

    def render
      return "".html_safe if @text.blank?

      mentions = []
      text_with_placeholders = substitute_mentions(@text, mentions)
      html = markdown_engine.render(text_with_placeholders)
      html = restore_mentions(html, mentions)

      Sanitize.fragment(html, SANITIZE_CONFIG).html_safe
    end

    private

    def substitute_mentions(text, mentions)
      html = text.gsub(ALL_TOKEN_REGEX) { mentions << all_mention_span; "\x02MENTION#{mentions.size - 1}\x03" }
      html.gsub(MENTION_REGEX) do
        name = Regexp.last_match(1)
        customer_id = Regexp.last_match(2)
        mentions << mention_span_or_plain(name, customer_id)
        "\x02MENTION#{mentions.size - 1}\x03"
      end
    end

    def restore_mentions(html, mentions)
      html.gsub(MENTION_TOKEN_REGEX) { mentions[Regexp.last_match(1).to_i] || Regexp.last_match(0) }
    end

    def mention_span_or_plain(name, customer_id)
      if @valid_customer_ids.include?(customer_id.to_i)
        %(<span class="chat-mention" data-customer-id="#{customer_id}">@#{CGI.escapeHTML(name)}</span>)
      else
        CGI.escapeHTML("@#{name}")
      end
    end

    def all_mention_span
      %(<span class="chat-mention chat-mention--all">@ALL</span>)
    end

    # MarkdownHelper#markdownと同じRedcarpet設定(filter_html/hard_wrap/autolink/tables/
    # fenced_code_blocks/strikethrough)を用いて、アプリ内の他のMarkdown欄と表示を揃える。
    def markdown_engine
      Redcarpet::Markdown.new(
        Redcarpet::Render::HTML.new(filter_html: true, hard_wrap: true),
        autolink: true,
        tables: true,
        fenced_code_blocks: true,
        strikethrough: true
      )
    end
  end
end
