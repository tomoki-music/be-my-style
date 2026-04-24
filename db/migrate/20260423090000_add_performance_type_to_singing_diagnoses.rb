class AddPerformanceTypeToSingingDiagnoses < ActiveRecord::Migration[6.1]
  def change
    add_column :singing_diagnoses, :performance_type, :integer, null: false, default: 0
    add_index :singing_diagnoses, :performance_type
  end
end
