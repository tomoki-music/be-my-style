# frozen_string_literal: true

class Public::ConfirmationsController < Devise::ConfirmationsController
  # GET /resource/confirmation/new
  # def new
  #   super
  # end

  # POST /resource/confirmation
  # def create
  #   super
  # end

  # GET /resource/confirmation?confirmation_token=abcdef
  # def show
  #   super
  # end

  protected

  # The path used after confirmation.
  def after_confirmation_path_for(resource_name, resource)
    if signed_in?(resource_name)
      signed_in_root_path(resource)
    elsif resource.singing_user?
      new_singing_customer_session_path
    elsif resource.business_user?
      new_business_customer_session_path
    elsif resource.learning_user?
      new_learning_customer_session_path
    else
      new_session_path(resource_name)
    end
  end
end
