class CreateChatMessagePins < ActiveRecord::Migration[6.1]
  def change
    create_table :chat_message_pins do |t|
      t.references :chat_message, null: false, foreign_key: true, index: { unique: true }
      t.references :pinned_by_customer, null: false, foreign_key: { to_table: :customers }, index: true

      t.timestamps
    end
  end
end
