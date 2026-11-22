module Admin::CustomerWithdrawalsHelper
  # 管理画面の退会確認で出す、退会を止める理由と運営としての対応方法。
  # 理由の判定は本人の退会と同じ Customers::Withdrawal::Plan::BLOCKER_KEYS(本人向けの文言は Accounts::WithdrawalsHelper)。
  ADMIN_WITHDRAWAL_BLOCKER_TEXTS = {
    system_admin: {
      title: "管理者(システム管理者)の会員です",
      resolution: "運営を続けるためのアカウントのため、退会できません。退会させる場合は、先にほかの運営者が「管理者設定」を変更してください。"
    },
    active_subscription: {
      title: "Stripe で有料プランを契約中です",
      resolution: "請求が続かないよう、退会の前に本人に解約してもらってください(管理画面からは Stripe の解約は行いません)。契約期間が終わってから退会できます。"
    },
    owned_communities: {
      title: "オーナーになっているコミュニティがあります",
      resolution: "コミュニティのオーナーを別の会員へ変更するか、コミュニティを削除してから退会してください。変更する相手には事前に了承を得てください。"
    },
    sole_manager_communities: {
      title: "ほかに運営者がいないコミュニティがあります",
      resolution: "この会員が抜けると管理できる人がいなくなります。別の運営者を追加してから退会してください。"
    },
    hosted_events: {
      title: "主催している、終了していないイベントがあります",
      resolution: "参加者がいるため、主催者の変更(相手の了承が必要)かイベントの扱いを本人・参加者と相談してから退会してください。終了したイベントは退会後も履歴として残ります。"
    },
    locked_entries: {
      title: "取消期限を過ぎたイベントへのエントリーがあります",
      resolution: "開始7日前を過ぎたイベント(開催中を含む)のエントリーは、退会でも自動では取り消しません。イベントの終了後に退会するか、主催者と相談してください。"
    },
    learning_students: {
      title: "学習サービスに登録した生徒がいます",
      resolution: "生徒への連絡が途切れないよう、本人に生徒の情報を整理してもらってから退会してください。"
    }
  }.freeze

  def admin_withdrawal_blocker_text(key)
    ADMIN_WITHDRAWAL_BLOCKER_TEXTS.fetch(key)
  end
end
