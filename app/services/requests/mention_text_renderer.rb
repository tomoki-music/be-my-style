module Requests
  # イベントリクエスト本文を安全な表示用HTMLへ変換する。
  #
  # Chat::MarkdownRendererと異なり、太字・見出し・リンク等のMarkdown記法は一切展開しない
  # (イベントリクエスト欄は従来通りプレーンテキスト表示のまま、メンションのみ対応する)。
  # 本文全体を確定的にCGI.escapeHTMLした上で、`[@表示名](customer:ID)`と予約トークン
  # `[@ALL](customer:all)`だけをChat::MarkdownRendererと同じ見た目の
  # <span class="chat-mention">へ変換する(正規表現自体はChat::MarkdownRenderer::MENTION_REGEXを
  # 再利用し、記法の定義を二重管理しない)。
  #
  # customer_idがvalid_customer_ids(=現在のイベント参加者)に含まれない場合は
  # メンション化せず、エスケープ済みの通常テキスト(`@表示名`)としてそのまま表示する。
  # 本文の改ざん・イベント参加状態の変化(離脱等)があっても、通知対象から除外することと
  # 表示上の扱いを一致させるための挙動であり、投稿の保存自体を失敗させることはない。
  class MentionTextRenderer
    MENTION_REGEX = Chat::MarkdownRenderer::MENTION_REGEX
    ALL_TOKEN_REGEX = /\[@ALL\]\(customer:all\)/.freeze

    def self.call(text, valid_customer_ids:)
      new(text, valid_customer_ids).render
    end

    def initialize(text, valid_customer_ids)
      @text = text.to_s
      @valid_customer_ids = valid_customer_ids.map(&:to_i).to_set
    end

    def render
      html = CGI.escapeHTML(@text)
      html = html.gsub(ALL_TOKEN_REGEX) { all_mention_span }
      html = html.gsub(MENTION_REGEX) do
        name = Regexp.last_match(1)
        customer_id = Regexp.last_match(2)
        mention_span_or_plain(name, customer_id)
      end
      html.html_safe
    end

    private

    def mention_span_or_plain(name, customer_id)
      if @valid_customer_ids.include?(customer_id.to_i)
        %(<span class="chat-mention" data-customer-id="#{customer_id}">@#{name}</span>)
      else
        "@#{name}"
      end
    end

    def all_mention_span
      %(<span class="chat-mention chat-mention--all">@ALL</span>)
    end
  end
end
