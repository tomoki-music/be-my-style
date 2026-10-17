class AddSystemGeneratedToChatMessages < ActiveRecord::Migration[6.1]
  def change
    # 締め切り自動リマインドなど、システムが自動投稿したメッセージの目印。
    # 画面で「自動お知らせ」と表示し、投稿者名義の人による本文編集を禁止する。
    add_column :chat_messages, :system_generated, :boolean, null: false, default: false
  end
end
