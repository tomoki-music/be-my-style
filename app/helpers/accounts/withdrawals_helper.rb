module Accounts::WithdrawalsHelper
  # 退会を止める理由ごとの見出しと解消方法。Customers::Withdrawal::Plan::BLOCKER_KEYS と対応させる。
  WITHDRAWAL_BLOCKER_TEXTS = {
    system_admin: {
      title: "運営(システム管理者)のアカウントです",
      resolution: "この画面からは退会できません。ほかの運営者に、管理者権限の解除を依頼してください。"
    },
    active_subscription: {
      title: "有料プランを契約中です",
      resolution: "プラン管理から解約してください。解約後も契約期間の終わりまではプランが続くため、期間が終わってから退会できます。"
    },
    owned_communities: {
      title: "オーナーになっているコミュニティがあります",
      resolution: "コミュニティを削除するか、オーナーの変更を運営へ依頼してください(オーナーは運営だけが変更できます)。"
    },
    sole_manager_communities: {
      title: "ほかに運営者がいないコミュニティがあります",
      resolution: "あなたが抜けると管理できる人がいなくなります。運営へ、別の運営者の追加を依頼してください。"
    },
    hosted_events: {
      title: "主催している、終了していないイベントがあります",
      resolution: "参加者がいるため、イベントを削除するか、主催者の変更を運営へ依頼してください。終了したイベントは退会後も履歴として残ります。"
    },
    locked_entries: {
      title: "取消期限を過ぎたイベントへのエントリーがあります",
      resolution: "開始7日前を過ぎたイベント(開催中を含む)のエントリーは、退会でも自動では取り消しません。イベントの終了後に退会するか、主催者に相談してください。"
    },
    learning_students: {
      title: "学習サービスに登録した生徒がいます",
      resolution: "生徒への連絡が途切れないよう、生徒の情報を削除してから退会してください。"
    }
  }.freeze

  def withdrawal_blocker_text(key)
    WITHDRAWAL_BLOCKER_TEXTS.fetch(key)
  end

  def withdrawal_community_path(community)
    community.business_domain? ? business_community_path(community) : public_community_path(community)
  end

  def withdrawal_entry_label(entry)
    song = entry.join_part.song
    "#{song.event.event_name} / #{song.song_name}(#{entry.join_part.join_part_name})"
  end
end
