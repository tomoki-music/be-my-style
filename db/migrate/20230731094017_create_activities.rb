class CreateActivities < ActiveRecord::Migration[6.1]
  def change
    create_table :activities do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :title
      t.text :introduction
      t.text :keep
      t.text :problem
      t.text :try
      t.timestamps
    end
  end
end
