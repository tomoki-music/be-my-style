module EventDeadlineReminders
  # メール配信の対象者。開催コミュニティに所属(CommunityCustomer=参加承認済み)していて、
  #   - 退会していない(is_deleted=false)
  #   - メールアドレス確認済み(Devise confirmable の confirmed_at あり)
  #   - メール受信設定がON(confirm_mail)
  #   - 有効な形式のメールアドレスを持つ
  # Customer。イベントへの参加登録の有無は問わない。
  class RecipientResolver
    EMAIL_FORMAT = URI::MailTo::EMAIL_REGEXP

    def self.call(event)
      new(event).call
    end

    def initialize(event)
      @event = event
    end

    def call
      return [] if @event.community_id.blank?

      scope.order(:id).to_a.select { |customer| customer.email.to_s.match?(EMAIL_FORMAT) }
    end

    # 送信直前の受信者単位の再確認(一覧取得から実送信までの間の退会・設定変更・コミュニティ退会に対応)。
    def eligible?(customer)
      return false if @event.community_id.blank?

      scope.exists?(id: customer.id) && customer.email.to_s.match?(EMAIL_FORMAT)
    end

    private

    def scope
      Customer
        .where(id: CommunityCustomer.where(community_id: @event.community_id).select(:customer_id))
        .active
        .where.not(confirmed_at: nil)
        .where(confirm_mail: true)
        .where.not(email: [nil, ""])
    end
  end
end
