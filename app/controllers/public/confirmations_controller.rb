# frozen_string_literal: true

class Public::ConfirmationsController < Devise::ConfirmationsController
  CONFIRMATION_REDIRECT_DOMAIN_PATHS = {
    "business" => :business_root_path,
    "learning" => :learning_root_path,
    "music" => :root_path,
    "singing" => :singing_root_path
  }.freeze

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
    customer = resource.reload
    path_helper = CONFIRMATION_REDIRECT_DOMAIN_PATHS.find do |domain_name, _|
      customer.has_domain?(domain_name)
    end&.last

    path_helper.present? ? public_send(path_helper) : root_path
  end
end
