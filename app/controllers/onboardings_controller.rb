class OnboardingsController < ApplicationController
  include BusinessReturnPath

  before_action :authenticate_customer!
  before_action :set_domain

  def step1
    @step = 1
  end

  def step2
    @step = 2

    @communities = Community
      .where(domain_id: @current_domain.id)

    @my_permits = current_customer.permits.pluck(:community_id)
  end

  def step3
    @step = 3
    session[:onboarding_activity_pending] = true
  end

  def complete
    current_customer.update(onboarding_done: true)

    if current_customer.business_user?
      # 招待用URLから登録した人は招待先へ、ログイン前に開こうとした Business の画面があればそこへ戻す。
      redirect_to business_path_after_onboarding(current_customer)
    else
      redirect_to root_path
    end
  end

  private

  def set_domain
    @current_domain =
      if current_customer.business_user?
        current_domain_business
      else
        current_domain_music
      end
  end
end