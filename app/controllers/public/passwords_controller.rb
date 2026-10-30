# frozen_string_literal: true

class Public::PasswordsController < Devise::PasswordsController
  # GET /resource/password/new
  # def new
  #   super
  # end

  # POST /resource/password
  # def create
  #   super
  # end

  # GET /resource/password/edit?reset_password_token=abcdef
  # def edit
  #   super
  # end

  # PUT /resource/password
  # def update
  #   super
  # end

  # protected

  # 再設定メールのリンク先は全ドメイン共通のため、利用資格に応じた行き先へ戻す。
  # 音楽会員(と管理者)は従来どおり音楽トップ、それ以外は音楽トップを経由させず各ドメインへ
  # (優先順は ApplicationController#non_music_domain_home_path と同じ)。
  def after_resetting_password_path_for(resource)
    return public_homes_top_path if resource.music_user? || resource.admin?
    return singing_root_path if resource.singing_user?
    return business_root_path if resource.business_user?
    return learning_root_path if resource.learning_user?

    public_homes_top_path
  end

  # The path used after sending reset password instructions
  def after_sending_reset_password_instructions_path_for(resource_name)
    public_homes_top_path
  end
end
