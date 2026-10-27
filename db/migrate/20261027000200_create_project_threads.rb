class CreateProjectThreads < ActiveRecord::Migration[6.1]
  DEFAULT_TITLE = "全体トーク".freeze

  # アプリのモデル(コールバック・検証)に依存しないよう、移行専用のクラスで扱う。
  class MigrationProject < ActiveRecord::Base
    self.table_name = "projects"
  end

  class MigrationProjectThread < ActiveRecord::Base
    self.table_name = "project_threads"
  end

  class MigrationProjectChat < ActiveRecord::Base
    self.table_name = "project_chats"
  end

  # 既存プロジェクトごとに「全体トーク」を1つ作り、既存のチャットをそこへ紐づける。
  # チャットの本文・投稿者・日時・添付(ActiveStorage は project_chats.id に紐づく)は書き換えない。
  # project_thread_id は NULL 許容のままにする: マイグレーション後〜Puma 再起動前に旧コードが
  # 書き込むチャットがあっても失敗させず、画面表示時(または rails business_project_threads:backfill)に紐づける。
  # customer_id(作成者)は NULL 許容: 作成者の会員データを完全削除してもスレッドとほかの参加者の会話を残す。
  # general は「全体トーク」だけ true、ほかは NULL。(project_id, general) の一意制約で、同時に補完されても
  # 1プロジェクトに1つしか作られない(NULL は一意制約の対象外なので通常のスレッドはいくつでも作れる)。
  #
  # MySQL の DDL はトランザクションで巻き戻らないため、途中で失敗しても再実行できるよう各手順を冪等にしている。
  def up
    unless table_exists?(:project_threads)
      create_table :project_threads do |t|
        t.references :project, null: false, foreign_key: true, index: false
        t.references :customer, null: true, foreign_key: true
        t.string :title, null: false
        t.text :description
        t.boolean :general
        t.datetime :last_posted_at, null: false
        t.timestamps
      end
    end
    add_column :project_threads, :general, :boolean unless column_exists?(:project_threads, :general)
    add_index :project_threads, [:project_id, :last_posted_at] unless index_exists?(:project_threads, [:project_id, :last_posted_at])
    add_index :project_threads, [:project_id, :general], unique: true unless index_exists?(:project_threads, [:project_id, :general])

    # add_reference は列・索引・外部キーを別々の文で作るため、途中で止まっても再実行で残りを作れるよう分けている。
    add_column :project_chats, :project_thread_id, :bigint unless column_exists?(:project_chats, :project_thread_id)
    add_index :project_chats, :project_thread_id unless index_exists?(:project_chats, :project_thread_id)
    add_foreign_key :project_chats, :project_threads unless foreign_key_exists?(:project_chats, :project_threads)

    MigrationProject.reset_column_information
    MigrationProjectThread.reset_column_information
    MigrationProjectChat.reset_column_information

    MigrationProject.find_each do |project|
      chats = MigrationProjectChat.where(project_id: project.id)
      now = Time.current
      thread = MigrationProjectThread.find_by(project_id: project.id, general: true) ||
               MigrationProjectThread.create!(
                 project_id: project.id,
                 customer_id: project.customer_id,
                 title: DEFAULT_TITLE,
                 general: true,
                 last_posted_at: chats.maximum(:created_at) || project.created_at || now,
                 created_at: project.created_at || now,
                 updated_at: now
               )
      chats.where(project_thread_id: nil).update_all(project_thread_id: thread.id)
    end
  end

  def down
    remove_reference :project_chats, :project_thread, foreign_key: true
    drop_table :project_threads
  end
end
