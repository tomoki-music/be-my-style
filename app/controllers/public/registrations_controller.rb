# frozen_string_literal: true

class Public::RegistrationsController < Devise::RegistrationsController
  before_action :configure_sign_up_params, only: [:create]
  before_action :configure_account_update_params, only: [:update]

  # GET /resource/sign_up
  def new
    super
    resource.domain_name = Customer::DEFAULT_SIGN_UP_DOMAIN if resource.domain_name.blank?
  end

  # POST /resource
  def create
    build_resource(sign_up_params)
    resource.domain_name = normalized_requested_domain_name
    resource.save

    yield resource if block_given?

    if resource.persisted?
      begin
        ActiveRecord::Base.transaction do
          attach_profile_image!(resource)
          attach_selected_domain!(resource)
        end
      rescue ActiveRecord::ActiveRecordError
        resource.destroy
        resource.errors.add(:base, "ドメイン設定の保存に失敗しました。")
        clean_up_passwords resource
        set_minimum_password_length
        return render :new
      end

      if resource.active_for_authentication?
        set_flash_message! :notice, :signed_up if is_flashing_format?
        sign_up(resource_name, resource)
        respond_with resource, location: after_sign_up_path_for(resource)
      else
        set_flash_message! :notice, :"signed_up_but_#{resource.inactive_message}" if is_flashing_format?
        expire_data_after_sign_in!
        respond_with resource, location: after_inactive_sign_up_path_for(resource)
      end
    else
      clean_up_passwords resource
      set_minimum_password_length
      respond_with resource
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

  protected

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
      :domain_name,
      part_ids: [],
      genre_ids: [],
      ]
    )
  end

  # If you have extra params to permit, append them to the sanitizer.
  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :profile_image])
  end

  #パスワードなしでcustomer情報変更
  def update_resource(resource, params)
    resource.update_without_password(params)
  end

  # The path used after sign up.
  def after_sign_up_path_for(resource)

    return singing_root_path if resource.singing_user?
    return onboarding_step1_path if resource.business_user? && !resource.onboarding_done
    return onboarding_step1_path if resource.music_user? && !resource.onboarding_done
    return learning_root_path if resource.learning_user?

    return business_root_path if resource.business_user?
    return root_path

  end

  # The path used after sign up for inactive accounts.
  def after_inactive_sign_up_path_for(resource)
    verify_path
  end

  private

  def normalized_requested_domain_name
    Customer::DEFAULT_SIGN_UP_DOMAIN
  end

  def attach_profile_image!(customer)
    return unless sign_up_params[:profile_image].present?

    customer.profile_image.attach(sign_up_params[:profile_image])
  end

  def attach_selected_domain!(customer)
    domain = Domain.find_or_create_by!(name: customer.normalized_domain_name)
    CustomerDomain.find_or_create_by!(customer: customer, domain: domain)
  end
end
