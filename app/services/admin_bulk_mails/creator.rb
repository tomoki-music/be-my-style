module AdminBulkMails
  # 確認画面の「送信する」で、一括メールを受け付けて宛先ごとの送信ジョブを入れる。
  #
  # - 送信対象は確定時にもう一度 RecipientResolver で読み直し、確認画面の fingerprint と違えば送らずに
  #   :changed を返す(確認後にアドレス・メール承認・送信可否が変わった場合に、対象を見直してもらう)。
  # - request_token は確認画面を出すたびに作り、admin_bulk_mails で一意にする。二重クリックや再送信で
  #   同じ token が来たら、新しく作らずに既存の送信を返す(:duplicate)。
  # - 宛先1人につき AdminBulkMailRecipient を1行作り、ジョブは行ごとに1通だけ送る(To は毎回1件)。
  class Creator
    Result = Struct.new(:status, :bulk_mail, :resolution, :errors, keyword_init: true)

    SKIPPED_IN_NON_PRODUCTION = "非本番環境のため送信しませんでした".freeze

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(admin:, customer_ids:, subject:, body:, request_token:, fingerprint:)
      @admin = admin
      @customer_ids = customer_ids
      @subject = subject.to_s
      @body = body.to_s
      @request_token = request_token.to_s
      @fingerprint = fingerprint.to_s
    end

    def call
      existing = AdminBulkMail.find_by(request_token: @request_token) if @request_token.present?
      return Result.new(status: :duplicate, bulk_mail: existing) if existing

      resolution = RecipientResolver.call(@customer_ids)
      bulk_mail = AdminBulkMail.new(admin: @admin, subject: @subject, body: @body, request_token: @request_token)
      return Result.new(status: :invalid, bulk_mail: bulk_mail, resolution: resolution, errors: bulk_mail.errors.full_messages) unless bulk_mail.valid?
      return Result.new(status: :no_recipients, bulk_mail: bulk_mail, resolution: resolution) if resolution.recipients.empty?
      unless ActiveSupport::SecurityUtils.secure_compare(resolution.fingerprint(@subject, @body), @fingerprint)
        return Result.new(status: :changed, bulk_mail: bulk_mail, resolution: resolution)
      end

      # SQL のログ(debug レベル)に件名・本文が出ないよう、保存の間だけ info 以上に絞る。
      ActiveRecord::Base.logger.silence(::Logger::INFO) do
        AdminBulkMail.transaction do
          bulk_mail.recipients_count = resolution.recipients.size
          bulk_mail.save!
          resolution.recipients.each do |customer|
            bulk_mail.recipients.create!(
              customer: customer,
              # 確認画面に出したアドレス(fingerprint で一致を確かめたもの)。送る直前にこれと照らす。
              email_digest: AdminBulkMailRecipient.email_digest_for(customer.email),
              status: delivery_allowed? ? :pending : :skipped,
              failure_reason: (SKIPPED_IN_NON_PRODUCTION unless delivery_allowed?)
            )
          end
        end
      end

      enqueue(bulk_mail) if delivery_allowed?
      Result.new(status: :created, bulk_mail: bulk_mail, resolution: resolution)
    rescue ActiveRecord::RecordNotUnique
      Result.new(status: :duplicate, bulk_mail: AdminBulkMail.find_by(request_token: @request_token))
    end

    private

    def enqueue(bulk_mail)
      bulk_mail.recipients.pluck(:id).each do |recipient_id|
        AdminBulkMailDeliveryJob.perform_later(recipient_id)
      end
    end

    # 開発環境は実際の SMTP 設定のため、実在の会員へ誤って送らないようにする(エントリー依頼メールと同じ考え方)。
    # test 環境は delivery_method=:test のため実際には送られない。
    def delivery_allowed?
      return @delivery_allowed if defined?(@delivery_allowed)

      @delivery_allowed =
        Rails.env.production? ||
        Rails.env.test? ||
        ENV["ADMIN_BULK_MAIL_ALLOW_REAL_EMAILS"].to_s.strip.length.positive?
    end
  end
end
