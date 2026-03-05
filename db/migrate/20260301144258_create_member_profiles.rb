class CreateMemberProfiles < ActiveRecord::Migration[6.1]
  def change
    create_table :member_profiles do |t|
      t.references :customer, null: false, foreign_key: true

      # アンケート由来
      t.string :entry_source              # どこで知ったか
      t.text   :join_reason               # 参加のきっかけ
      t.text   :want_to_do                # やりたいこと

      # enum管理
      t.integer :music_experience_level, null: false, default: 0
      t.integer :engagement_style,        null: false, default: 0
      t.integer :suggested_member_type,   null: false, default: 0

      # 運営用
      t.integer :contact_preference,      null: false, default: 0
      t.text    :admin_memo               # 管理者メモ

      t.timestamps
    end
  end
end
