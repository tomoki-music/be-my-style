class Business::HomesController < ApplicationController
  include MemberHome

  skip_before_action :authenticate_customer!, only: [:top]

  # 未ログインでは紹介ページを出し、プロジェクトの名前・件数を含め何も取得しない。
  def top
    load_member_home if customer_signed_in?
  end
end
