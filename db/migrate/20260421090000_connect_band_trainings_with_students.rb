class ConnectBandTrainingsWithStudents < ActiveRecord::Migration[6.1]
  def change
    add_column :learning_band_trainings, :related_parts, :text

    create_table :learning_band_memberships do |t|
      t.references :learning_band, null: false, foreign_key: true
      t.references :learning_student, null: false, foreign_key: true

      t.timestamps
    end

    add_index :learning_band_memberships, [:learning_band_id, :learning_student_id], unique: true, name: "index_learning_band_memberships_on_band_and_student"
  end
end
