class CreateCustomerSongParts < ActiveRecord::Migration[6.1]
  def change
    # 自己申告の演奏可能曲(customer x song_master x part)。CustomerPart(担当パート自己申告)と
    # 同じ考え方で、こちらは「曲+パート」単位の自己申告を保持する。
    create_table :customer_song_parts do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :song_master, null: false, foreign_key: true
      # 登録時に選んだ具体的なSong(表示・所属コミュニティ確認用)。Song削除後も
      # 自己申告自体は残すため、song_performancesと同様にnullable + dependent: :nullify。
      t.references :song, null: true, foreign_key: true
      t.string :part_name, null: false

      t.timestamps
    end

    # customer x song_master x part の重複登録を防ぐ。全カラムNOT NULL運用のため、
    # song_performancesと違いevent_id相当の可変カラムを持たず、MySQLのUNIQUE index上の
    # NULL問題が構造的に発生しない。
    add_index :customer_song_parts, [:customer_id, :song_master_id, :part_name],
      unique: true, name: "index_customer_song_parts_on_customer_song_and_part"
  end
end
