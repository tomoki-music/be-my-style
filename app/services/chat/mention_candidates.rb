module Chat
  # @メンション候補として提示可能な(かつメンション作成時にも権限を満たす)Customerを返す。
  # 候補取得API・メンション保存時の権限検証の両方から本サービスを参照することで、
  # 「候補に出せる=実際にメンションできる」を単一のロジックで保証する。
  class MentionCandidates
    MAX_RESULTS = 20
    MAX_QUERY_LENGTH = 50

    # DM: 相手(自分以外の参加者)のみ。
    def self.for_chat_room(chat_room:, current_customer:, query: nil)
      new(chat_room.customers, current_customer, query).search
    end

    # コミュニティチャット: 実際のコミュニティメンバー(CommunityCustomer経由)のみ。
    # ChatRoomCustomerは「このチャットルームを開いたことがあるか」に過ぎず、
    # 全メンバーを網羅しないため候補の母集団には使わない。
    def self.for_community(community:, current_customer:, query: nil)
      new(community.customers, current_customer, query).search
    end

    # イベントリクエスト欄: イベントへ現在参加登録しており、かつ開催元コミュニティの
    # 有効メンバーでもあるCustomerのみ(Event#mentionable_participants)。
    # 参加登録していないコミュニティメンバー・参加後にコミュニティを退会した人は候補にならない。
    # オーナー・管理者も参加登録かつコミュニティ所属の両方を満たさなければ候補にならない。
    # 候補表示用にMAX_RESULTS件へ絞るため、通知対象の解決にはこのメソッドを経由せず
    # Requests::MentionResolverが直接Event#mentionable_participantsを使う。
    def self.for_event(event:, current_customer:, query: nil)
      new(event.mentionable_participants, current_customer, query).search
    end

    def initialize(base_scope, current_customer, query)
      raise ArgumentError, "current_customer is required" if current_customer.blank? || current_customer.id.blank?

      @base_scope = base_scope
      @current_customer = current_customer
      @query = query
    end

    def search
      # テーブル名を明示してcustomers.idを指定する(has_many :through の結合先テーブルの
      # idと曖昧にならないよう、Railsの暗黙解決に頼らずここで確定させる)。
      scope = @base_scope.where.not(customers: { id: @current_customer.id }).distinct

      if @query.present?
        sanitized = ActiveRecord::Base.sanitize_sql_like(@query.to_s.strip.first(MAX_QUERY_LENGTH).downcase)
        scope = scope.where("LOWER(customers.name) LIKE ?", "%#{sanitized}%")
      end

      scope.order(:name).limit(MAX_RESULTS)
    end
  end
end
