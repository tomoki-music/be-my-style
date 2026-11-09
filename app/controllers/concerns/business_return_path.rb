# 未ログインで開こうとした Business の画面(共有URLなど)へ、ログイン・確認メール・利用開始・オンボーディングの後に戻すための判定。
# 戻り先は Devise が未ログイン時に保存したパス(stored_location_for)だけを使い、URL のパラメータからは受け取らない。
module BusinessReturnPath
  extend ActiveSupport::Concern

  # ログイン・登録・パスワード再設定・利用開始の画面へ戻すとループするため、戻り先にしない。
  BUSINESS_AUTH_PATHS = %w[/business/sign_in /business/sign_up /business/password /business/join].freeze

  # オンボーディングを挟む間だけ、Devise の保存先から移しておくセッションのキー。
  ONBOARDING_RETURN_KEY = :business_return_to_after_onboarding

  # 招待先(Business::SignupInvitations)が期限切れ・削除済みだったときの案内。
  INVITATION_UNAVAILABLE_MESSAGE =
    "招待されたコミュニティ・プロジェクトを開けませんでした（削除されたか、招待の有効期限が切れています）。ホームから探してください。".freeze
  # 招待先のプロジェクトを開くには、先に親コミュニティへの参加が必要なときの案内。
  INVITATION_AWAITING_COMMUNITY_MESSAGE =
    "招待されたプロジェクト「%<title>s」を開くには、先にこのコミュニティへの参加が必要です。参加が成立すると、プロジェクトへご案内します。".freeze

  private

  # アプリ内の Business の画面(パスのみ)に限る。"//host" のような外部へ向かう形は受け付けない。
  def restorable_business_path?(path)
    path = path.to_s
    return false unless path == "/business" || path.start_with?("/business/", "/business?")
    return false if path.include?("//") || path.include?("\\")

    BUSINESS_AUTH_PATHS.none? { |auth_path| path == auth_path || path.start_with?("#{auth_path}/", "#{auth_path}?") }
  end

  # 保存された戻り先を1回だけ取り出す。Business の画面でなければ捨てて nil を返す。
  def take_business_return_path(customer)
    path = stored_location_for(customer).to_s
    restorable_business_path?(path) ? path : nil
  end

  def keep_business_return_path_for_onboarding(path)
    session[ONBOARDING_RETURN_KEY] = path if restorable_business_path?(path)
  end

  def take_business_return_path_after_onboarding
    path = session.delete(ONBOARDING_RETURN_KEY).to_s
    restorable_business_path?(path) ? path : nil
  end

  # オンボーディング完了後の Business の遷移先。招待用URLから登録した人の招待先(会員に記録)を優先し、
  # 無ければ従来どおりセッションで預かった戻り先、それも無ければ Business ホーム。
  # 招待先が期限切れ・削除済みなら、案内を出して Business ホームへ戻す。招待先・戻り先はどちらも1回で消費する。
  def business_path_after_onboarding(customer)
    return_path = take_business_return_path_after_onboarding
    invitation = Business::SignupInvitations::Take.call(customer)

    case invitation.status
    when :ok then invitation.path
    when :awaiting
      flash[:notice] = business_invitation_awaiting_message(invitation.record)
      invitation.path
    when :invalid
      flash[:alert] = INVITATION_UNAVAILABLE_MESSAGE
      business_root_path
    else
      return_path || business_root_path
    end
  end

  def business_invitation_awaiting_message(project)
    format(INVITATION_AWAITING_COMMUNITY_MESSAGE, title: project.title)
  end
end
