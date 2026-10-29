class Business::HomesController < ApplicationController
  include MemberHome

  skip_before_action :authenticate_customer!, only: [:top]

  # ログイン前は紹介ページ(従来のヘッダー)のまま、ログイン後だけ Business の枠を使う。
  layout -> { customer_signed_in? ? "business" : "application" }

  # 未ログインでは紹介ページを出し、プロジェクトの名前・件数を含め何も取得しない。
  def top
    load_member_home(with_images: true) if customer_signed_in?
  end
end
