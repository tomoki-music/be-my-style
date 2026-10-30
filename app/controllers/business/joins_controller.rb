class Business::JoinsController < ApplicationController
  include DomainJoinable
  include BusinessReturnPath

  domain_auth_for :business

  private

  # 音楽などのアカウントで Business の利用を始めたとき、ログイン前に開こうとした Business の画面へ戻す。
  def after_domain_join_path
    take_business_return_path(current_customer) || super
  end
end
