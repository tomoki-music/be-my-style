# frozen_string_literal: true

class Public::SessionsController < Devise::SessionsController
  before_action :configure_permitted_parameters, if: :devise_controller?

  def after_sign_in_path_for(resource)
    session.delete(:customer_sign_out_redirect_to)

    case detect_login_domain
    when "singing"
      singing_root_path
    when "business"
      if resource.business_user? && !resource.onboarding_done
        onboarding_step1_path
      else
        business_root_path
      end
    when "learning"
      learning_root_path
    else
      if resource.music_user? && !resource.onboarding_done
        onboarding_step1_path
      else
        root_path
      end
    end
  end

  def after_sign_out_path_for(_resource)
    scoped_sign_out_redirect_path || public_homes_top_path
  end

  private

  def detect_login_domain
    path = request.path.to_s
    return "singing"  if path.start_with?("/singing")
    return "business" if path.start_with?("/business")
    return "learning" if path.start_with?("/learning")
    "music"
  end

  def scoped_sign_out_redirect_path
    referer_path = URI.parse(request.referer.to_s).path

    return new_singing_customer_session_path if referer_path.start_with?("/singing")
    return new_business_customer_session_path if referer_path.start_with?("/business")
    return new_learning_customer_session_path if referer_path.start_with?("/learning")

    session.delete(:customer_sign_out_redirect_to)
  rescue URI::InvalidURIError
    public_homes_top_path
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name])
  end
  
  # before_action :configure_sign_in_params, only: [:create]

  # GET /resource/sign_in
  # def new
  #   super
  # end

  # POST /resource/sign_in
  # def create
  #   super
  # end

  # DELETE /resource/sign_out
  # def destroy
  #   super
  # end

  # protected

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_in_params
  #   devise_parameter_sanitizer.permit(:sign_in, keys: [:attribute])
  # end
end
