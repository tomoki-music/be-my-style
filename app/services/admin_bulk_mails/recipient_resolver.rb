require "digest"

module AdminBulkMails
  # 選択された会員 ID から、一括メールの送信対象と除外を決める。
  # メールアドレスはフォームから受け取らず、ここで会員の DB の値から読む。
  # 確認画面・確定・ジョブの送信直前で同じ判定を使う。
  class RecipientResolver
    EXCLUSION_REASONS = {
      not_found: "会員が見つからない",
      withdrawn: "退会済み",
      no_email: "メールアドレスがない",
      invalid_email: "メールアドレスが無効",
      mail_opt_out: "メール通知を受け取らない設定"
    }.freeze

    EMAIL_FORMAT = URI::MailTo::EMAIL_REGEXP

    Result = Struct.new(:recipients, :exclusions, keyword_init: true) do
      def unconfirmed_recipients
        recipients.select { |customer| customer.confirmed_at.nil? }
      end

      def exclusion_counts
        exclusions.group_by { |exclusion| exclusion[:reason] }.transform_values(&:size)
      end

      # 確認画面で見た「送信対象・件名・本文」と、確定時に読み直したものが同じかを比べるための値。
      # 宛先のアドレス・メール承認・送信可否が変わったら値が変わる。
      def fingerprint(subject, body)
        parts = recipients.map { |customer| [customer.id, customer.email, customer.confirmed_at.present?].join(":") }
        parts += exclusions.map { |exclusion| "x#{exclusion[:customer_id]}:#{exclusion[:reason]}" }
        Digest::SHA256.hexdigest([subject.to_s, body.to_s, *parts].join("\n"))
      end
    end

    def self.call(customer_ids)
      new(customer_ids).call
    end

    # 1人分の送信可否(送信直前の再確認に使う)。送れるなら nil、送れないなら除外理由。
    def self.exclusion_reason_for(customer)
      return :not_found if customer.nil?
      return :withdrawn unless customer.notifiable?
      return :no_email if customer.email.blank?
      return :invalid_email unless customer.email.match?(EMAIL_FORMAT)
      return :mail_opt_out unless customer.confirm_mail

      nil
    end

    def self.normalize_ids(customer_ids)
      Array(customer_ids).flat_map { |value| value.to_s.split(",") }
                         .map(&:strip).select { |value| value.match?(/\A\d+\z/) }
                         .map(&:to_i).select(&:positive?).uniq.sort
    end

    def initialize(customer_ids)
      @customer_ids = self.class.normalize_ids(customer_ids)
    end

    def call
      customers_by_id = Customer.where(id: @customer_ids).index_by(&:id)
      recipients = []
      exclusions = []

      @customer_ids.each do |customer_id|
        customer = customers_by_id[customer_id]
        reason = self.class.exclusion_reason_for(customer)
        if reason
          exclusions << { customer_id: customer_id, customer: customer, reason: reason }
        else
          recipients << customer
        end
      end

      Result.new(recipients: recipients, exclusions: exclusions)
    end
  end
end
