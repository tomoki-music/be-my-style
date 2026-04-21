class ApplicationController < ActionController::Base
  FEATURE_CATALOG = {
    music_direct_chat: {
      required_plan: "light",
      title: "個別チャット",
      message: "lightプラン以上で個別チャットが使えます。気になる相手と、もっと深くつながりたい方におすすめです。",
      cta: "lightへアップグレード",
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
      required_plan: "light",
      title: "活動報告の投稿",
      message: "活動報告の投稿はlightプラン以上で利用できます。あなたの活動を仲間に届けましょう。",
      cta: "lightで投稿を始める",
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
  
  helper_method :current_domain_business
  helper_method :current_domain_music
  helper_method :current_domain_learning
  helper_method :feature_available?
  helper_method :feature_gate
  helper_method :feature_upgrade_path
  helper_method :feature_required_plan
  helper_method :feature_upgrade_cta

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
      else
        Domain.find_by(name: "music")
      end
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

end
