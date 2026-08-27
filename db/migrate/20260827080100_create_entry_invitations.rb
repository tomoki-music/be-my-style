class CreateEntryInvitations < ActiveRecord::Migration[6.1]
  def change
    # イベント楽曲の演奏経験者へ送る「エントリー依頼メール」の送信履歴。
    # 経験者一覧(PerformanceHistory::ExperiencedCustomersQuery)から選んだ人へ、
    # 曲×募集中パート単位で個別送信した記録を保持し、連続送信防止(24h)と
    # 送信結果(依頼済み/失敗)の画面表示に使う。
    create_table :entry_invitations do |t|
      t.references :event,     null: false, foreign_key: true
      t.references :song,      null: false, foreign_key: true
      t.references :join_part, null: false, foreign_key: true
      # 受信者(経験者)
      t.references :customer,  null: false, foreign_key: true
      # 送信者(管理者/コミュニティ管理権限者/イベント作成者)
      t.references :requested_by_customer, null: false, foreign_key: { to_table: :customers }
      t.datetime :sent_at
      t.integer  :status, null: false, default: 0
      t.string   :failure_reason
      t.timestamps
    end

    # (event, song, join_part, customer) につき常に1行。再送は既存行を UPDATE する。
    # 二重クリック・並行リクエストによる2本目の INSERT は RecordNotUnique となり、
    # アプリ側で「24h以内は再送不可」として安全に無視できる。
    # 全キーカラムが NOT NULL のため、MySQL の UNIQUE index における NULL 重複問題は起きない。
    add_index :entry_invitations,
              [:event_id, :song_id, :join_part_id, :customer_id],
              unique: true,
              name: "index_entry_invitations_on_event_song_part_customer"
  end
end
