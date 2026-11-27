# 管理画面 TOP のメンバー一覧から、選んだ会員へ名前入りのメールを送る。
# 作成(compose) → 確認(preview) → 送信(create) の順で進み、確定は確認画面のボタンだけから行う。
# 宛先のメールアドレスはフォームから受け取らず、会員 ID から毎回 DB で読む。
class Admin::BulkMailsController < ApplicationController
  NO_RECIPIENTS_MESSAGE = "送信できるメンバーがいないため、送信できません。除外の理由を確認してください。".freeze

  before_action :authenticate_admin!

  def index
    @bulk_mails = AdminBulkMail.includes(:admin).order(created_at: :desc).limit(50)
  end

  def show
    @bulk_mail = AdminBulkMail.find(params[:id])
    @status_counts = @bulk_mail.status_counts
    @recipients = @bulk_mail.recipients.includes(:customer).order(:id)
  end

  def compose
    @customer_ids = AdminBulkMails::RecipientResolver.normalize_ids(params[:customer_ids])
    if @customer_ids.empty?
      redirect_to admin_homes_top_path, alert: "メールを送るメンバーを選んでください。"
      return
    end

    @subject = subject_param
    @body = body_param
    @resolution = AdminBulkMails::RecipientResolver.call(@customer_ids)
  end

  def preview
    @customer_ids = AdminBulkMails::RecipientResolver.normalize_ids(params[:customer_ids])
    @subject = subject_param
    @body = body_param
    @resolution = AdminBulkMails::RecipientResolver.call(@customer_ids)

    errors = AdminBulkMail.new(subject: @subject, body: @body, request_token: "-").tap(&:valid?).errors.full_messages
    if errors.any?
      flash.now[:alert] = errors.join(" / ")
      render :compose, status: :unprocessable_entity
      return
    end

    if @resolution.recipients.empty?
      flash.now[:alert] = NO_RECIPIENTS_MESSAGE
      render_preview(status: :unprocessable_entity)
      return
    end

    render_preview
  end

  def create
    result = AdminBulkMails::Creator.call(
      admin: current_admin,
      customer_ids: params[:customer_ids],
      subject: subject_param,
      body: body_param,
      request_token: params[:request_token],
      fingerprint: params[:fingerprint]
    )

    case result.status
    when :created
      Rails.logger.info("[Admin::BulkMailsController] accepted bulk_mail_id=#{result.bulk_mail.id} admin_id=#{current_admin.id} recipients=#{result.bulk_mail.recipients_count}")
      redirect_to admin_bulk_mail_path(result.bulk_mail), notice: "#{result.bulk_mail.recipients_count}件のメールを受け付けました。送信状況はこの画面で確認できます。"
    when :duplicate
      redirect_to admin_bulk_mail_path(result.bulk_mail), notice: "このメールはすでに受け付け済みです(重複して送信していません)。"
    else
      @customer_ids = AdminBulkMails::RecipientResolver.normalize_ids(params[:customer_ids])
      @subject = subject_param
      @body = body_param
      @resolution = result.resolution
      if result.status == :no_recipients
        flash.now[:alert] = NO_RECIPIENTS_MESSAGE
        render_preview(status: :unprocessable_entity)
      elsif result.status == :changed
        flash.now[:alert] = "確認後に送信対象(メールアドレス・メール承認・送信可否)が変わりました。まだ送信していません。内容を見直してから、もう一度「送信する」を押してください。"
        render_preview(status: :conflict)
      else
        flash.now[:alert] = (result.errors.presence || ["送信できるメンバーがいません。"]).join(" / ")
        render :compose, status: :unprocessable_entity
      end
    end
  end

  private

  # 確認画面の hidden 項目を経由すると改行が CRLF / LF のどちらでも届きうるため、LF にそろえる
  # (そろえないと確認時と確定時で fingerprint が一致しない)。
  def body_param
    mail_params[:body].to_s.gsub(/\r\n?/, "\n")
  end

  def subject_param
    mail_params[:subject].to_s.gsub(/[\r\n]+/, " ").strip
  end

  # 件名・本文は bulk_mail[...] で受け取り、filter_parameters でログから伏せる。
  def mail_params
    params.fetch(:bulk_mail, {}).permit(:subject, :body)
  end

  def render_preview(status: :ok)
    @request_token = SecureRandom.urlsafe_base64(24)
    @fingerprint = @resolution.fingerprint(@subject, @body)
    @preview_customer = @resolution.recipients.first
    render :preview, status: status
  end
end
