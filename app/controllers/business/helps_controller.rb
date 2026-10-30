# NAKAMA の使い方。ログイン前から読めるよう認証を外し、会員データは一切取得しない。
class Business::HelpsController < ApplicationController
  skip_before_action :authenticate_customer!

  # ログイン後は左ナビ・下部ナビ付きの Business の枠、ログイン前は紹介ページと同じヘッダー・フッターで出す。
  layout -> { customer_signed_in? ? "business" : "application" }

  def show
  end
end
