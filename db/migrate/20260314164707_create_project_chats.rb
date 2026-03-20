class CreateProjectChats < ActiveRecord::Migration[6.1]
  def change
    create_table :project_chats do |t|
      t.references :project, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.text :body

      t.timestamps
    end
  end
end
