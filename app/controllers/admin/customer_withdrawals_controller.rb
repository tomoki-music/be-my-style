# 管理画面からの会員の退会。本人による退会(Accounts::WithdrawalsController)と同じ
# Customers::Withdrawal::Plan / Execute を使い、止める理由・削除する情報・通知の扱いを本人の退会と揃える。
#
# - 会員編集フォームで会員状態「退会」を選んで保存すると、ほかの変更は保存せずに確認画面(new)へ進む。
# - 確定(create)は POST のみ。対象は URL の会員 ID だけで決め、確認欄に同じ ID を入力したときだけ実行する。
# - 止める理由は管理者でも無視しない(所有権の移譲・イベントの中止・解約を勝手に行わない)。
# - 旧方式の退会(is_deleted のみ)の会員は、編集画面の専用ボタンからだけここへ来る(通常の再保存では来ない)。
#   退会扱い(ログイン不可・通知停止)のまま Execute に通し、個人情報の削除などを行う。
class Admin::CustomerWithdrawalsController < ApplicationController
  LOG_TAG = "[Admin::CustomerWithdrawalsController]".freeze

  before_action :authenticate_admin!
  before_action :set_customer
  before_action :redirect_if_already_withdrawn
  before_action :reject_own_account

  helper_method :legacy_deleted?

  def new
    @plan = Customers::Withdrawal::Plan.new(@customer)
  end

  def create
    unless params[:confirmation_customer_id].to_s.strip == @customer.id.to_s
      render_new_with_alert("確認欄に会員 ID「#{@customer.id}」を入力してください。退会は実行していません。")
      return
    end

    begin
      # 旧方式の会員かどうかは DB の状態だけで決める(画面から送られた値は使わない)。
      result = Customers::Withdrawal::Execute.call(@customer, include_legacy_deleted: legacy_deleted?)
    rescue ActiveRecord::ActiveRecordError => e
      # 退会の DB 更新は1つのトランザクションのため、ここに来たときは何も変わっていない。
      Rails.logger.error("#{LOG_TAG} withdrawal failed customer_id=#{@customer.id} #{e.class}")
      @customer.reload
      render_new_with_alert("退会の処理に失敗しました。会員の情報は変更していません。時間をおいてもう一度お試しください。")
      return
    end

    if result.blocked?
      @plan = result.plan
      flash.now[:alert] = "退会を確定できない理由があります。下の案内に沿って解消してから、もう一度お試しください。"
      render :new, status: :unprocessable_entity
      return
    end

    if result.already_withdrawn?
      redirect_to edit_admin_customer_path(@customer), notice: "会員 ID #{@customer.id} はすでに退会済みです。"
      return
    end

    Rails.logger.info("#{LOG_TAG} withdrawn customer_id=#{@customer.id} admin_id=#{current_admin.id}")
    redirect_to edit_admin_customer_path(@customer), notice: "会員 ID #{@customer.id} の退会を確定しました。"
  end

  private

  def set_customer
    @customer = Customer.find(params[:customer_id])
  end

  # 退会の手続きが済んだ会員(withdrawn_at あり)は、ここでは何もしない。
  def redirect_if_already_withdrawn
    return unless @customer.withdrawn?

    redirect_to edit_admin_customer_path(@customer), alert: "会員 ID #{@customer.id} はすでに退会の手続きが済んでいます。"
  end

  # 旧方式の退会(管理画面で is_deleted だけを立てた会員。個人情報は残っている)。
  def legacy_deleted?
    @customer.is_deleted? && !@customer.withdrawn?
  end

  # 操作している運営者自身の会員アカウント。退会するとこの管理画面にも入れなくなる。
  def reject_own_account
    return unless current_customer.present? && current_customer.id == @customer.id

    redirect_to edit_admin_customer_path(@customer), alert: "ご自身のアカウントは管理画面から退会できません。"
  end

  def render_new_with_alert(message)
    @plan = Customers::Withdrawal::Plan.new(@customer)
    flash.now[:alert] = message
    render :new, status: :unprocessable_entity
  end
end
