class Public::HomesController < ApplicationController
  include MemberHome

  skip_before_action :authenticate_customer!, only: [:top]

  def top
    return render("public/homes/guest_top") unless customer_signed_in?

    load_member_home
  end

  def about
  end
end
