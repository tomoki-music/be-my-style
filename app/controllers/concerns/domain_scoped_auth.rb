module DomainScopedAuth
  extend ActiveSupport::Concern

  DOMAIN_AUTH_CONFIG = {
    singing: {
      domain_name: "singing",
      domain_label: "Singing",
      member_predicate: :singing_user?,
      sign_in_route: :new_singing_customer_session_path,
      sign_up_route: :new_singing_customer_registration_path,
      password_route: :new_singing_customer_password_path,
      session_route: :singing_customer_session_path,
      registration_route: :singing_customer_registration_path,
      password_create_route: :singing_customer_password_path,
      join_route: :singing_join_path,
      root_route: :singing_root_path,
      back_route: :public_singing_lp_path,
      join_back_route: :root_path,
      back_label: "歌唱診断サービスについて",
      theme_class: "domain-auth--singing",
      session_title: "ログイン",
      session_lead: "歌唱・演奏診断サービスへようこそ",
      registration_title: "新規登録",
      registration_lead: "歌唱・演奏診断を始めましょう",
      password_title: "パスワードをお忘れですか？",
      password_lead: "メールアドレスを入力するとリセット用のメールをお送りします",
      join_title: "AI歌唱診断サービスへようこそ",
      join_lead: "このアカウントで歌唱診断サービスを利用開始できます",
      join_notice: "歌唱診断サービスの利用を開始しました。",
      join_features: [
        { icon: "♪", text: "音声アップロードで演奏・歌唱スキルを数値化" },
        { icon: "↑", text: "診断履歴で自分の成長を可視化" },
        { icon: "*", text: "Premium ではAIによる個別コメントも利用可能" }
      ]
    },
    business: {
      domain_name: "business",
      domain_label: "Business",
      member_predicate: :business_user?,
      sign_in_route: :new_business_customer_session_path,
      sign_up_route: :new_business_customer_registration_path,
      password_route: :new_business_customer_password_path,
      session_route: :business_customer_session_path,
      registration_route: :business_customer_registration_path,
      password_create_route: :business_customer_password_path,
      join_route: :business_join_path,
      root_route: :business_root_path,
      back_route: :business_root_path,
      join_back_route: :business_root_path,
      back_label: "ビジネスコミュニティへ戻る",
      theme_class: "domain-auth--business",
      session_title: "ログイン",
      session_lead: "NAKAMA ビジネスコミュニティへようこそ",
      registration_title: "新規登録",
      registration_lead: "投稿・プロジェクト・コミュニティを始めましょう",
      password_title: "パスワード再設定",
      password_lead: "登録メールアドレス宛に再設定用メールをお送りします",
      join_title: "Businessドメインの利用を開始しますか？",
      join_lead: "このアカウントでNAKAMAの投稿・プロジェクト機能を利用開始できます",
      join_notice: "ビジネスコミュニティの利用を開始しました。",
      join_features: [
        { icon: "#", text: "知見や募集を投稿して、つながりを広げられます" },
        { icon: "+", text: "プロジェクトを立ち上げて、仲間集めを始められます" },
        { icon: "@", text: "コミュニティに参加して、継続的な交流を育てられます" }
      ]
    },
    learning: {
      domain_name: "learning",
      domain_label: "Learning",
      member_predicate: :learning_user?,
      sign_in_route: :new_learning_customer_session_path,
      sign_up_route: :new_learning_customer_registration_path,
      password_route: :new_learning_customer_password_path,
      session_route: :learning_customer_session_path,
      registration_route: :learning_customer_registration_path,
      password_create_route: :learning_customer_password_path,
      join_route: :learning_join_path,
      root_route: :learning_root_path,
      back_route: :public_homes_top_path,
      join_back_route: :public_homes_top_path,
      back_label: "BeMyStyleトップへ戻る",
      theme_class: "domain-auth--learning",
      session_title: "ログイン",
      session_lead: "Learningドメインの管理画面へようこそ",
      registration_title: "新規登録",
      registration_lead: "生徒の進捗管理を始めるアカウントを作成します",
      password_title: "パスワード再設定",
      password_lead: "登録メールアドレスに再設定案内を送信します",
      join_title: "Learningドメインの利用を開始しますか？",
      join_lead: "このアカウントで生徒管理・進捗ダッシュボードを利用開始できます",
      join_notice: "Learningドメインの利用を開始しました。",
      join_features: [
        { icon: "o", text: "高校グループと生徒情報をまとめて管理できます" },
        { icon: "=", text: "ダッシュボードで達成率や今週のMVPを確認できます" },
        { icon: ">", text: "トレーニング割当と進捗ログを一つの画面で追えます" }
      ]
    }
  }.freeze

  included do
    class_attribute :domain_auth_key, instance_accessor: false
    helper_method :domain_auth_config
  end

  class_methods do
    def domain_auth_for(key)
      self.domain_auth_key = key.to_sym
    end
  end

  private

  def domain_auth_config
    DOMAIN_AUTH_CONFIG.fetch(self.class.domain_auth_key)
  end

  def domain_member?(resource)
    resource.public_send(domain_auth_config[:member_predicate])
  end

  def auth_domain_name
    domain_auth_config[:domain_name]
  end

  def auth_join_path
    public_send(domain_auth_config[:join_route])
  end

  def auth_sign_in_path
    public_send(domain_auth_config[:sign_in_route])
  end

  def auth_root_path
    public_send(domain_auth_config[:root_route])
  end
end
