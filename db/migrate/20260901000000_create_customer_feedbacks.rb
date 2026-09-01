class CreateCustomerFeedbacks < ActiveRecord::Migration[6.1]
  def change
    # ログインユーザーが運営へ送る「ご意見・ご相談BOX」の投稿。
    # category / status は日本語を保存せず整数 enum（英語識別値）で持ち、表示時に I18n で変換する。
    create_table :customer_feedbacks do |t|
      # 投稿者。退会(customers.is_deleted)してもレコードは残す運用のため、
      # 既存の他テーブルと同じく RESTRICT の外部キー。完全削除(purge)時は
      # Customer 側 has_many dependent: :destroy で一緒に削除される。
      t.references :customer, null: false, foreign_key: true

      # 0: feature_request / 1: bug_report / 2: consultation / 3: other
      # 既存 enum(Post 等)と同じ整数バッキング。値の並び替え・再利用は不可。
      # category はユーザーの必須選択項目。DB デフォルトを持たせると未選択/パラメータ欠落時に
      # 意図せず feature_request として保存され得るため、あえて default を設定しない
      # (presence バリデーションと組み合わせて未選択を確実に弾く)。
      t.integer :category, null: false

      # 件名は任意。長い件名でもレイアウトを崩さないようモデル側で 100 文字上限。
      t.string :subject

      t.text :body, null: false

      # 0: unread(未確認) / 1: reviewing(確認中) / 2: completed(対応済み)
      t.integer :status, null: false, default: 0

      # 運営内部メモ。一般ユーザーには表示しない。
      t.text :admin_note

      t.timestamps
    end

    # 管理画面の対応状況フィルタ用。
    add_index :customer_feedbacks, :status
    # 一覧(新着順)・履歴の並び替え用。
    add_index :customer_feedbacks, :created_at
  end
end
