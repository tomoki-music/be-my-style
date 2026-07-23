class CreateChatMessageLinkPreviews < ActiveRecord::Migration[6.1]
  def change
    create_table :chat_message_link_previews do |t|
      t.references :chat_message, null: false, foreign_key: true
      t.integer :provider, null: false, default: 0
      t.string :url, null: false
      t.string :external_id, null: false
      t.integer :position, null: false
      t.integer :status, null: false, default: 0
      t.string :title
      t.string :author_name
      t.string :thumbnail_url
      t.text :failure_reason
      t.datetime :fetched_at

      t.timestamps
    end

    add_index :chat_message_link_previews, [:chat_message_id, :position], unique: true
    add_index :chat_message_link_previews, [:provider, :external_id]
  end
end
