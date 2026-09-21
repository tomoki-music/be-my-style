class CreateCaptionVideos < ActiveRecord::Migration[6.1]
  def change
    # AIテロップ動画作成機能(MVP)。元動画をアップロードし、音声抽出→文字起こし→
    # テロップ編集→焼き込みという一連の非同期処理をこのレコード1件が表す。
    create_table :caption_videos do |t|
      t.references :customer, null: false, foreign_key: true

      t.string :title, null: false

      # uploaded / extracting_audio / transcribing / ready_for_edit /
      # rendering / completed / failed
      # SingingGeneratedRecapMovie に倣い文字列バッキングの enum とする。
      # 整数バッキングは並び替え・欠番で事故りやすいため避ける。
      t.string :status, null: false, default: "uploaded"

      # 動画の長さ(秒)。ffprobe で取得。テロップ同期の精度確保のため decimal。
      t.decimal :duration, precision: 8, scale: 3

      # ffprobe で取得した元動画の解像度。ASS字幕の PlayResX/Y や画面占有率の計算に使う。
      t.integer :width
      t.integer :height
      # 表示用ラベル(例: "16:9" "9:16")。width/height から導出して保存する。
      t.string :aspect_ratio

      t.text :error_message

      t.datetime :processing_started_at
      t.datetime :processing_completed_at

      # MVPでは "standard" 固定。将来複数テンプレートを追加できるようカラムを用意しておく。
      t.string :selected_template, null: false, default: "standard"

      # MVPでは日本語固定だが、将来の多言語対応に備えてカラム化しておく。
      t.string :transcript_language, null: false, default: "ja"

      # 各非同期ステップの冪等性・二重課金防止用タイムスタンプ。
      # (例: transcribed_at が入っていれば TranscribeJob は再実行しても OpenAI を呼ばない)
      t.datetime :audio_extracted_at
      t.datetime :transcribed_at

      t.timestamps
    end

    add_index :caption_videos, :status
    add_index :caption_videos, :created_at
  end
end
