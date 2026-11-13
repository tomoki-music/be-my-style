# BeMyStyle アカウントの退会(音楽・歌声・Business・学習の全サービス共通)。コミュニティ単位の「退会」とは別。
# 確定はログイン中の本人だけが、POST とパスワードの再入力で行う(CSRF 対策は ApplicationController の既定のまま)。
class Accounts::WithdrawalsController < ApplicationController
  BACK_DESTINATIONS = %w[music business singing learning].freeze

  skip_before_action :authenticate_customer!, only: [:complete]
  before_action :set_back_path, only: [:new, :create]

  def new
    @plan = Customers::Withdrawal::Plan.new(current_customer)
  end

  def create
    unless current_customer.valid_password?(params[:current_password].to_s)
      @plan = Customers::Withdrawal::Plan.new(current_customer)
      flash.now[:alert] = "パスワードが正しくありません。"
      render :new, status: :unprocessable_entity
      return
    end

    begin
      result = Customers::Withdrawal::Execute.call(current_customer)
    rescue ActiveRecord::ActiveRecordError => e
      # 退会の DB 更新は1つのトランザクションのため、ここに来たときは何も変わっていない。
      Rails.logger.error("[Accounts::WithdrawalsController] withdrawal failed customer_id=#{current_customer.id} #{e.class}")
      @plan = Customers::Withdrawal::Plan.new(current_customer.reload)
      flash.now[:alert] = "退会の処理に失敗しました。アカウントは変更していません。時間をおいてもう一度お試しください。"
      render :new, status: :unprocessable_entity
      return
    end

    if result.blocked?
      @plan = result.plan
      flash.now[:alert] = "退会を確定できない理由があります。下の案内に沿って解消してください。"
      render :new, status: :unprocessable_entity
      return
    end

    # 退会済み(二重送信の2回目を含む)。この端末のログインを解除して完了画面へ。
    sign_out(:customer)
    redirect_to complete_account_withdrawal_path
  end

  def complete
  end

  private

  # 「戻る」の行き先。外部 URL へ戻さないよう、決まったサービスのトップだけにする。
  def set_back_path
    @from = BACK_DESTINATIONS.include?(params[:from]) ? params[:from] : default_back_destination
    @back_path =
      case @from
      when "business" then business_root_path
      when "singing" then singing_root_path
      when "learning" then learning_root_path
      else public_homes_top_path
      end
  end

  def default_back_destination
    return "music" if current_customer.music_user? || current_customer.admin?
    return "singing" if current_customer.singing_user?
    return "business" if current_customer.business_user?
    return "learning" if current_customer.learning_user?

    "music"
  end
end
