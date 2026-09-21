class CreateVideoCaptions < ActiveRecord::Migration[6.1]
  def change
    # 文字起こし結果を整形した「テロップ1件」。開始/終了は decimal(8,3) で
    # ミリ秒精度を保持し、動画との同期ズレを防ぐ。
    create_table :video_captions do |t|
      t.references :caption_video, null: false, foreign_key: true

      t.decimal :start_time, precision: 8, scale: 3, null: false
      t.decimal :end_time,   precision: 8, scale: 3, null: false

      t.text :text, null: false

      # normal(MVP既定) / main / sub / emphasis / heading / annotation
      # 将来のAI自動分類機能で使う想定。整数enumだと分類ロジック追加のたびに
      # マイグレーションと対応表の同期が必要になり事故りやすいため文字列で持つ。
      t.string :caption_type, null: false, default: "normal"

      # 画面内の表示位置。MVPでは "bottom_center" 固定だが将来の配置切り替えに備える。
      t.string :position, null: false, default: "bottom_center"

      # テロップの並び順。start_time が同一/近接するケースでも順序を安定させる。
      t.integer :display_order, null: false, default: 0

      # 将来のAI自動分類(メイン/サブ/強調の判定根拠・信頼度など)を保存する領域。
      # MVPでは未使用(nil)。
      t.text :emphasis_data

      # ユーザーが手動編集したテロップかどうか。将来AIが再分類する際に、
      # 手動編集済みのものを上書きしないための判定に使う。
      t.boolean :manually_edited, null: false, default: false

      t.timestamps
    end

    add_index :video_captions, [:caption_video_id, :display_order]
  end
end
