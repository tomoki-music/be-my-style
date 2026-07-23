module Chat
  # チャットルーム内メッセージのキーワード部分一致検索。
  # 通常メッセージ・スレッド返信の両方を検索対象にし、常にchat_room_idでスコープする
  # (呼び出し側でChat::ChatRoomAuthorization.readable?による認可確認が済んでいる前提)。
  class MessageSearch
    MIN_QUERY_LENGTH = 2
    MAX_QUERY_LENGTH = 50
    PER_PAGE = 20

    Result = Struct.new(:status, :messages, :page, :total_pages, :total_count, keyword_init: true) do
      def ok?
        status == :ok
      end
    end

    def self.call(chat_room:, query:, page: 1)
      new(chat_room, query, page).search
    end

    def initialize(chat_room, query, page)
      @chat_room = chat_room
      @query = query.to_s.strip
      @page = page.to_i.positive? ? page.to_i : 1
    end

    def search
      return blank_result(query_status) unless query_status == :ok

      sanitized = ActiveRecord::Base.sanitize_sql_like(@query.downcase)
      # sanitize_sql_likeはバックスラッシュでエスケープするが、MySQLと異なりSQLite(test環境)は
      # デフォルトのLIKEエスケープ文字を持たないため、ESCAPE句を明示してDBに依存せず動作させる。
      scope = @chat_room.chat_messages
                .where("LOWER(content) LIKE ? ESCAPE '\\'", "%#{sanitized}%")
                .includes(:customer, reply_to_chat_message: :customer)
                .with_attached_attachments
                .order(created_at: :desc)
                .page(@page).per(PER_PAGE)

      Result.new(
        status: :ok,
        messages: scope,
        page: scope.current_page,
        total_pages: scope.total_pages,
        total_count: scope.total_count
      )
    end

    private

    def query_status
      return :blank if @query.blank?
      return :too_short if @query.length < MIN_QUERY_LENGTH
      return :too_long if @query.length > MAX_QUERY_LENGTH

      :ok
    end

    def blank_result(status)
      Result.new(status: status, messages: ChatMessage.none.page(1), page: 1, total_pages: 0, total_count: 0)
    end
  end
end
