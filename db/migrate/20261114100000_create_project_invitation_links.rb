require_relative "../../lib/migration_lock_wait_timeout"

class CreateProjectInvitationLinks < ActiveRecord::Migration[6.1]
  include MigrationLockWaitTimeout

  # プライベート(招待制)プロジェクトの招待リンク。トークンそのものは保存せず、SHA-256 のダイジェストだけを持つ
  # (DB を読めてもリンクを復元できないようにする。リンクは発行直後の画面にだけ表示し、見失ったら再発行する)。
  # 有効なリンクはプロジェクトごとに1本。再発行・無効化では行を消さずに revoked_at を記録する(期限切れ・無効化の案内に使う)。
  #
  # business_signup_invitations.project_invitation_link_id は、招待リンクから新規登録した人の招待元。
  # 確認メールを別のブラウザで開いても、オンボーディング完了時に招待を受け入れられるよう会員単位で持つ。
  #
  # 途中で失敗しても再実行できるよう、テーブル・列・外部キーの有無を確認してから作る(MySQL の DDL は巻き戻らない)。
  def up
    unless table_exists?(:project_invitation_links)
      create_table :project_invitation_links do |t|
        t.references :project, null: false, foreign_key: true
        t.string :token_digest, null: false, limit: 64
        t.datetime :expires_at, null: false
        t.datetime :revoked_at
        t.bigint :created_by_id
        t.integer :used_count, null: false, default: 0
        t.datetime :last_used_at
        t.timestamps
      end
    end

    add_index :project_invitation_links, :token_digest, unique: true unless index_exists?(:project_invitation_links, :token_digest)
    add_index :project_invitation_links, :created_by_id unless index_exists?(:project_invitation_links, :created_by_id)
    unless foreign_key_exists?(:project_invitation_links, :customers, column: :created_by_id)
      add_foreign_key :project_invitation_links, :customers, column: :created_by_id, on_delete: :nullify
    end

    unless column_exists?(:business_signup_invitations, :project_invitation_link_id)
      add_column :business_signup_invitations, :project_invitation_link_id, :bigint
    end
    unless index_exists?(:business_signup_invitations, :project_invitation_link_id)
      add_index :business_signup_invitations, :project_invitation_link_id
    end
    unless foreign_key_exists?(:business_signup_invitations, :project_invitation_links)
      add_foreign_key :business_signup_invitations, :project_invitation_links, on_delete: :nullify
    end
  end

  def down
    if foreign_key_exists?(:business_signup_invitations, :project_invitation_links)
      remove_foreign_key :business_signup_invitations, :project_invitation_links
    end
    if column_exists?(:business_signup_invitations, :project_invitation_link_id)
      remove_column :business_signup_invitations, :project_invitation_link_id
    end
    drop_table :project_invitation_links if table_exists?(:project_invitation_links)
  end
end
