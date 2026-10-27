class CreateBusinessMembershipTables < ActiveRecord::Migration[6.1]
  # Business のプロジェクト参加申請と、コミュニティ・プロジェクトのアクセス停止。
  # 参加済み(community_customers / project_members)・コミュニティの承認待ち(permits)は既存テーブルをそのまま使う。
  # 途中で失敗しても再実行できるよう、テーブルごとに有無を確認してから作る(MySQL の DDL は巻き戻らない)。
  def up
    # 手動承認プロジェクトへの承認待ち申請。承認・却下・取り消しで行を消す(却下後は再申請できる)。
    unless table_exists?(:project_join_requests)
      create_table :project_join_requests do |t|
        t.references :project, null: false, foreign_key: true
        t.references :customer, null: false, foreign_key: true
        t.timestamps
      end
    end
    add_index :project_join_requests, [:project_id, :customer_id], unique: true unless index_exists?(:project_join_requests, [:project_id, :customer_id])

    # 管理者によるアクセス停止。行がある間は手動・自動どちらの方式でも参加・申請できない。
    create_suspension_table(:community_access_suspensions, :community, "index_community_access_suspensions_uniqueness")
    create_suspension_table(:project_access_suspensions, :project, "index_project_access_suspensions_uniqueness")
  end

  def down
    drop_table :project_access_suspensions, if_exists: true
    drop_table :community_access_suspensions, if_exists: true
    drop_table :project_join_requests, if_exists: true
  end

  private

  def create_suspension_table(table, target, index_name)
    unless table_exists?(table)
      create_table table do |t|
        t.references target, null: false, foreign_key: true
        t.references :customer, null: false, foreign_key: true
        t.references :suspended_by, foreign_key: { to_table: :customers }
        t.timestamps
      end
    end
    add_index table, [:"#{target}_id", :customer_id], unique: true, name: index_name unless index_exists?(table, [:"#{target}_id", :customer_id], name: index_name)
  end
end
