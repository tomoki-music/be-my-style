class CreateProjects < ActiveRecord::Migration[6.1]
  def change
    create_table :projects do |t|
      t.references :community, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.string :title
      t.text :description

      t.timestamps
    end
  end
end
