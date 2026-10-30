# frozen_string_literal: true

class Public::SessionsController < Devise::SessionsController
  before_action :configure_permitted_parameters, if: :devise_controller?

  # 未ログイン時に保存された戻り先は、どのドメインでログインしても1回で取り出して捨てる。
  # 使うのは Business のログインのときだけで、古い戻り先が後の音楽・歌声ログインに残らないようにする。
  def after_sign_in_path_for(resource)
    session.delete(:customer_sign_out_redirect_to)
    stored_path = stored_location_for(resource).to_s

    case detect_login_domain
    when "singing"
      singing_root_path
    when "business"
      business_after_sign_in_path(resource, stored_path)
    when "learning"
      learning_root_path
    else
      # 音楽のログイン画面から入った Business だけの利用者は、音楽トップ(/)を経由させず Business へ進める。
      return business_after_sign_in_path(resource, stored_path) if business_only_customer?(resource)

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

  # ログイン・登録・パスワード再設定・利用開始の画面へ戻すとループするため、戻り先にしない。
  BUSINESS_AUTH_PATHS = %w[/business/sign_in /business/sign_up /business/password /business/join].freeze

  # 未ログインで開こうとした Business の画面があれば、ログイン後にそこへ戻す(Business 以外の保存先は使わない)。
  def business_after_sign_in_path(resource, stored_path)
    return onboarding_step1_path if resource.business_user? && !resource.onboarding_done

    restorable_business_path?(stored_path) ? stored_path : business_root_path
  end

  # アプリ内の Business の画面(パスのみ)に限る。"//host" のような外部へ向かう形は受け付けない。
  def restorable_business_path?(path)
    return false unless path == "/business" || path.start_with?("/business/", "/business?")
    return false if path.include?("//") || path.include?("\\")

    BUSINESS_AUTH_PATHS.none? { |auth_path| path == auth_path || path.start_with?("#{auth_path}/", "#{auth_path}?") }
  end

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
