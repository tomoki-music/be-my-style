# CSRF 検証に失敗した送信を、英語の 422 画面(public/422.html)ではなく開き直しの案内に変える。
#
# 正規の利用者でも、ログイン・ログアウト・ブラウザ再起動でセッションのトークンが作り直された後に、
# 開いたままの古い画面(別タブ・戻る操作・復元されたタブ)から送信すると失敗する。
# 検証そのもの(verify_authenticity_token)は変えず、送信内容は実行も再送もしない。
module CsrfRejectionRecovery
  EXPIRED_FORM_MESSAGE = "画面の有効期限が切れました。お手数ですが、画面を開き直してからもう一度操作してください。".freeze

  private

  # 検証の途中で Rails がセッションにトークンを作るため、失敗理由の分類用に検証前の有無を覚えておく。
  def capture_csrf_session_state
    @csrf_session_token_present = session[:_csrf_token].present?
  end

  def recover_from_invalid_authenticity_token
    log_csrf_rejection

    if request.format.html? && !request.xhr?
      redirect_to csrf_rejection_return_path, alert: EXPIRED_FORM_MESSAGE, status: :see_other
    else
      render json: { error: EXPIRED_FORM_MESSAGE }, status: :unprocessable_entity
    end
  end

  # トークンや Cookie の値は出さず、原因の切り分けに必要な種別だけを残す(request_id はログタグで付く)。
  def log_csrf_rejection
    Rails.logger.warn(
      "[CSRF] rejected reason=#{csrf_rejection_reason} method=#{request.request_method} path=#{request.path} " \
      "action=#{controller_path}##{action_name} format=#{request.format&.symbol || 'unknown'} xhr=#{request.xhr?} " \
      "session_token=#{@csrf_session_token_present ? 'present' : 'absent'} " \
      "signed_in=#{csrf_rejection_signed_in_scopes} referer=#{csrf_rejection_referer_summary} " \
      "sec_fetch_site=#{request.headers['Sec-Fetch-Site'].presence || 'none'}"
    )
  end

  # Rails の検証順(Origin → トークン)に合わせて、どこで落ちたかを分類する。
  def csrf_rejection_reason
    origin = request.origin
    if self.class.forgery_protection_origin_check && origin.present?
      return "origin_null" if origin == "null"
      return "origin_mismatch" if origin != request.base_url
    end
    return "token_missing" if params[request_forgery_protection_token].blank? && request.x_csrf_token.blank?
    return "session_token_missing" unless @csrf_session_token_present

    "token_mismatch"
  end

  # Warden の認証処理(remember Cookie でのログインなど)を走らせないよう、セッションのキーだけを見る。
  def csrf_rejection_signed_in_scopes
    scopes = Devise.mappings.keys.select { |scope| session["warden.user.#{scope}.key"].present? }
    scopes.any? ? scopes.join(",") : "none"
  end

  def csrf_rejection_referer_summary
    return "none" if request.referer.blank?

    # クエリにはパスワード再設定のトークンなどが入りうるので、ログにはパスだけを残す。
    same_origin_referer_path&.split("?", 2)&.first || "other_origin"
  end

  def csrf_rejection_return_path
    same_origin_referer_path || csrf_rejection_fallback_path
  end

  # 外部サイトへは戻さない(オープンリダイレクト防止)。
  def same_origin_referer_path
    return if request.referer.blank?

    uri = URI.parse(request.referer)
    return unless uri.is_a?(URI::HTTP) && uri.host == request.host && uri.port == request.port && uri.scheme == request.scheme

    path = uri.path.presence || "/"
    return unless path.start_with?("/") && !path.start_with?("//")

    uri.query.present? ? "#{path}?#{uri.query}" : path
  rescue URI::InvalidURIError
    nil
  end

  def csrf_rejection_fallback_path
    path = request.path
    return business_root_path if path.start_with?("/business")
    return singing_root_path if path.start_with?("/singing")
    return learning_root_path if path.start_with?("/learning")

    root_path
  end

  # ログイン・登録などの画面は、戻る操作やタブの復元で古いトークンのまま送信されやすいので保存させない。
  def prevent_caching_of_authentication_forms
    return unless request.get? && devise_controller?

    response.cache_control[:no_store] = true
  end
end
