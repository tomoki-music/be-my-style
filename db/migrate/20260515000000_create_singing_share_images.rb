class CreateSingingShareImages < ActiveRecord::Migration[6.1]
  def change
    create_table :singing_share_images do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :capture_target, null: false
      t.integer :status, null: false, default: 0
      t.datetime :expires_at, null: false
      t.datetime :generated_at
      t.json :metadata

      t.timestamps
    end

    add_index :singing_share_images, :capture_target
    add_index :singing_share_images, :status
    add_index :singing_share_images, :expires_at
    add_index :singing_share_images, [:customer_id, :capture_target]
  end
end
