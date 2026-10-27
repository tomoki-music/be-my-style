class AddJoinApprovalModeToCommunitiesAndProjects < ActiveRecord::Migration[6.1]
  # 0 = 手動承認 / 1 = 自動承認。
  # communities: 既存の参加は「申請 → 運営者が承認」だったため、既存行・新規行とも手動承認(0)。
  #   music のコミュニティにも列は付くが、参照するのは Business の画面だけ。
  # projects: 既存の参加は「コミュニティ参加者なら即参加」だったため、既存行は自動承認(1)で
  #   追加してから、新規作成の既定値だけを手動承認(0)へ切り替える。
  # 途中で失敗しても再実行できるよう、列の有無を確認してから追加する(MySQL の DDL は巻き戻らない)。
  def up
    add_column :communities, :join_approval_mode, :integer, null: false, default: 0 unless column_exists?(:communities, :join_approval_mode)

    add_column :projects, :join_approval_mode, :integer, null: false, default: 1 unless column_exists?(:projects, :join_approval_mode)
    change_column_default :projects, :join_approval_mode, from: 1, to: 0
  end

  def down
    remove_column :projects, :join_approval_mode
    remove_column :communities, :join_approval_mode
  end
end
