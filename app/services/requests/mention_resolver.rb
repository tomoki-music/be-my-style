module Requests
  # イベントリクエスト投稿本文からメンション対象Customerを解決する。
  #
  # 個別メンションはChat::MentionParserと同じ`[@表示名](customer:ID)`記法をそのまま再利用する。
  # `@ALL`はcustomer:0やcustomer:-1のような数値IDの偽装を避け、`[@ALL](customer:all)`という
  # 明確に区別できる予約トークンとして専用に検出する(customer_idは常に数値のため衝突しない)。
  #
  # 対象は必ず「イベント参加者 かつ 開催元コミュニティの有効メンバー」
  # (Event#mentionable_participants)との積集合に絞り込むため、本文を改ざんして
  # 未参加者・他コミュニティのCustomer IDを送信しても通知対象には含まれない(サーバー側検証)。
  # Chat::MentionCandidates.for_eventは候補表示用にMAX_RESULTS件へ切り詰めるため、
  # 通知対象の解決では取りこぼしを避けるためあえて経由せず、同じEvent#mentionable_participantsを直接使う。
  class MentionResolver
    ALL_TOKEN_REGEX = /\[@ALL\]\(customer:all\)/.freeze

    def self.call(request_text:, event:, poster:)
      new(request_text, event, poster).resolve
    end

    def initialize(request_text, event, poster)
      @request_text = request_text.to_s
      @event = event
      @poster = poster
    end

    def resolve
      return eligible_scope.to_a if mentions_all?

      mentioned_ids = Chat::MentionParser.call(@request_text)
      return [] if mentioned_ids.blank?

      eligible_scope.where(id: mentioned_ids).to_a
    end

    private

    def mentions_all?
      @request_text.match?(ALL_TOKEN_REGEX)
    end

    def eligible_scope
      @event.mentionable_participants.where.not(id: @poster.id)
    end
  end
end
