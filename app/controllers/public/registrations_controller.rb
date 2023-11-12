# frozen_string_literal: true

class Public::RegistrationsController < Devise::RegistrationsController
  before_action :configure_sign_up_params, only: [:create]
  before_action :configure_account_update_params, only: [:update]

  # GET /resource/sign_up
  # def new
  #   super
  # end

  # POST /resource
  def create
    super
    if sign_up_params[:profile_image].present?
      resource.profile_image.attach(sign_up_params[:profile_image])    
    end
  end

  # GET /resource/edit
  # def edit
  #   super
  # end

  # PUT /resource
  # def update
  #   super
  # end

  # DELETE /resource
  # def destroy
  #   super
  # end

  def verify
  end

  # def remail
  #   Customer.find(11).send_confirmation_instructions
  #   redirect_to public_homes_top_path
  # end
  # GET /resource/cancel
  # Forces the session data which is usually expired after sign
  # in to be expired now. This is useful if the user wants to
  # cancel oauth signing in/up in the middle of the process,
  # removing all OAuth session data.
  # def cancel
  #   super
  # end

  # protected

  # If you have extra params to permit, append them to the sanitizer.
  def configure_sign_up_params
    devise_parameter_sanitizer.permit(
      :sign_up, keys: [
      :name,
      :part,
      :sex,
      :birthday,
      :activity_stance,
      :favorite_artist1,
      :favorite_artist2,
      :favorite_artist3,
      :favorite_artist4,
      :favorite_artist5,
      :introduction,
      :profile_image,
      :prefecture_id,
      :url,
      part_ids: [],
      genre_ids: [],
      ]
    )
  end

  # If you have extra params to permit, append them to the sanitizer.
  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :profile_image])
  end

  # The path used after sign up.
  def after_sign_up_path_for(resource)
    public_homes_top_path
  end

  # The path used after sign up for inactive accounts.
  def after_inactive_sign_up_path_for(resource)
    verify_path
  end
end
