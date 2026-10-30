module Business
  # コミュニティ・プロジェクトの通常画面の「招待用URL」。
  # 通常画面のパスだけを共有し、検索条件・会員ID・認証情報・招待トークンは含めない(開いた人の参加・閲覧条件は変わらない)。
  module ShareHelper
    def business_share_url(record)
      options = Rails.application.config.x.business_share_url_options

      case record
      when Community then business_community_url(record, **options)
      when Project then business_project_url(record, **options)
      else raise ArgumentError, "共有URLを作れない種類です: #{record.class.name}"
      end
    end

    # 共有URLの近くに出す、開いた人に必要な手順の説明。参加方式ごとに実際の条件(JoinCommunity / JoinProject)に合わせる。
    def business_share_note(record)
      case record
      when Community
        approval = record.join_auto? ? "「参加する」を押すとすぐに参加できます" : "参加には運営者の承認が必要です"
        "開いた人はNAKAMAへのログイン（未登録なら新規登録）が必要です。#{approval}。コミュニティ内の会話やメンバーは、参加した人だけが見られます。"
      when Project
        approval = record.join_auto? ? "そのあと「参加する」を押すと参加できます" : "そのうえでプロジェクト管理者の承認が必要です"
        "開いた人はNAKAMAへのログインと、先にコミュニティ「#{record.community.name}」への参加が必要です。#{approval}。スレッドやメンバーは、参加した人だけが見られます。"
      end
    end
  end
end
