class ApplicationController < ActionController::Base
  FEATURE_CATALOG = {
    music_direct_chat: {
      required_plan: "free",
      title: "個別チャット",
      message: "freeプランから個別チャットが使えます。相互フォローの相手と、もっと気軽につながれます。",
      cta: "無料でチャットを始める",
      upgrade_path: -> { public_lp_path(anchor: "lp-section") }
    },
    music_community_chat: {
      required_plan: "light",
      title: "コミュニティチャット",
      message: "lightプラン以上でコミュニティチャットに参加できます。メンバー同士の会話をもっと深めたい方におすすめです。",
      cta: "lightでチャットを開放",
      upgrade_path: -> { public_lp_path(anchor: "lp-section") }
    },
    music_activity_create: {
      required_plan: "free",
      title: "活動ログの投稿",
      message: "Freeプランでも活動ログを投稿できます。まずは気軽に音楽活動を記録しましょう。",
      cta: "無料で活動を記録する",
      upgrade_path: -> { public_lp_path(anchor: "lp-section") }
    },
    music_event_create: {
      required_plan: "core",
      title: "イベント作成",
      message: "イベント作成はcoreプラン以上で利用できます。参加する側から、企画する側へ進みたい方におすすめです。",
      cta: "coreでイベントを作成",
      upgrade_path: -> { public_lp_path(anchor: "lp-section") }
    },
    music_community_mail: {
      required_plan: "premium",
      title: "コミュニティ一斉メール",
      message: "一斉連絡はpremiumプランで利用できます。コミュニティ運営をもっとスムーズに進められます。",
      cta: "premiumで運営機能を開放",
      upgrade_path: -> { public_lp_path(anchor: "lp-section") }
    },
    music_community_create: {
      required_plan: "premium",
      title: "コミュニティ作成",
      message: "コミュニティ作成はpremiumプランで利用できます。あなたのテーマで新しい場をつくれます。",
      cta: "premiumでコミュニティを作成",
      upgrade_path: -> { public_lp_path(anchor: "lp-section") }
    },
    business_post_create: {
      required_plan: "light",
      title: "ビジネス投稿",
      message: "投稿機能はlightプラン以上で利用できます。知見や近況を発信して、つながりを広げられます。",
      cta: "lightで投稿を始める",
      upgrade_path: -> { business_root_path(anchor: "business-pricing") }
    },
    business_community_post_create: {
      required_plan: "light",
      title: "コミュニティ内投稿",
      message: "コミュニティ内投稿はlightプラン以上で利用できます。所属コミュニティの交流をもっと活性化できます。",
      cta: "lightでコミュニティ投稿を開放",
      upgrade_path: -> { business_root_path(anchor: "business-pricing") }
    },
    business_project_create: {
      required_plan: "core",
      title: "プロジェクト作成",
      message: "プロジェクト作成はcoreプラン以上で利用できます。仲間を集めて、企画を前に進めたい方におすすめです。",
      cta: "coreでプロジェクトを始める",
      upgrade_path: -> { business_root_path(anchor: "business-pricing") }
    },
    business_community_create: {
      required_plan: "premium",
      title: "コミュニティ作成",
      message: "コミュニティ作成はpremiumプランで利用できます。あなたのテーマで新しい場をつくれます。",
      cta: "premiumでコミュニティを作成",
      upgrade_path: -> { business_root_path(anchor: "business-pricing") }
    }
  }.freeze

  before_action :set_current_domain
  before_action :authenticate_customer!
  before_action :ensure_music_domain_access_for_public_routes!
  
  helper_method :current_domain_business
  helper_method :current_domain_music
  helper_method :current_domain_learning
  helper_method :current_domain_singing
  helper_method :feature_available?
  helper_method :feature_gate
  helper_method :feature_upgrade_path
  helper_method :feature_required_plan
  helper_method :feature_upgrade_cta
  helper_method :onboarding_activity_exception?

  # ActiveAdmin initializer historically referenced AdminUser helpers.
  # Keep compatibility so custom admin pages under /admin remain stable.
  def authenticate_admin_user!
    authenticate_admin!
  end

  def current_admin_user
    current_admin
  end

  private

  def set_current_domain
    @current_domain =
      if request.path.start_with?("/business")
        Domain.find_by(name: "business")
      elsif request.path.start_with?("/learning")
        Domain.find_by(name: "learning")
      elsif request.path.start_with?("/singing")
        Domain.find_by(name: "singing")
      else
        Domain.find_by(name: "music")
      end
  end

  def ensure_music_domain_access_for_public_routes!
    return unless public_music_platform_route?
    return if current_customer&.admin?
    return if current_customer&.music_user?

    redirect_to non_music_domain_home_path, alert: "音楽プラットフォームの利用には音楽ドメインの登録が必要です。"
  end

  def public_music_platform_route?
    path = request.path
    return false unless path == "/" || path.start_with?("/public")

    public_shared_route_exceptions.none? { |prefix| path.start_with?(prefix) }
  end

  def public_shared_route_exceptions
    [
      "/public/lp",
      "/public/legal",
      "/public/terms",
      "/public/privacy",
      "/public/checkout",
      "/public/stripe",
      "/public/portal",
      "/public/webhooks"
    ]
  end

  def non_music_domain_home_path
    return singing_root_path if current_customer&.singing_user?
    return business_root_path if current_customer&.business_user?
    return learning_root_path if current_customer&.learning_user?

    new_customer_session_path
  end

  def admin_only!
    redirect_to root_path, alert: "管理者のみ操作可能です。" unless current_customer&.admin?
  end

  def current_domain_business
    Domain.find_by(name: "business")
  end

  def current_domain_music
    Domain.find_by(name: "music")
  end

  def current_domain_learning
    Domain.find_by(name: "learning")
  end

  def current_domain_singing
    Domain.find_by(name: "singing")
  end

  def feature_available?(feature_key, customer = current_customer)
    customer.present? && customer.has_feature?(feature_key)
  end

  def feature_gate(feature_key)
    FEATURE_CATALOG.fetch(feature_key.to_sym)
  end

  def feature_required_plan(feature_key)
    feature_gate(feature_key)[:required_plan]
  end

  def feature_upgrade_cta(feature_key)
    feature_gate(feature_key)[:cta]
  end

  def feature_upgrade_path(feature_key)
    instance_exec(&feature_gate(feature_key)[:upgrade_path])
  end

  def require_feature!(feature_key, redirect_to_path: nil)
    return if feature_available?(feature_key)

    redirect_to(
      redirect_to_path || feature_upgrade_path(feature_key),
      alert: feature_gate(feature_key)[:message]
    )
  end

  # music / business オンボーディング中の Free ユーザーに活動報告を1回だけ許可する例外判定。
  # サーバー側で (1)ドメイン一致 (2)未完了 (3)step3 経由 を複合チェックする。
  def onboarding_activity_exception?(domain_name)
    return false unless current_customer.present?
    return false if current_customer.onboarding_done?
    return false unless session[:onboarding_activity_pending]
    current_customer.has_domain?(domain_name.to_s)
  end

  # オンボーディング導線からの投稿成功時にオンボーディングを完了扱いにする。
  def complete_onboarding_if_pending!
    return if current_customer.onboarding_done?
    return unless session[:onboarding_activity_pending]

    session.delete(:onboarding_activity_pending)
    current_customer.update!(onboarding_done: true)
  end

end
