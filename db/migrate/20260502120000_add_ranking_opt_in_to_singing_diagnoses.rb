class AddRankingOptInToSingingDiagnoses < ActiveRecord::Migration[6.1]
  def change
    add_column :singing_diagnoses, :ranking_opt_in, :boolean, default: false, null: false
    add_index :singing_diagnoses, :ranking_opt_in
  end
end
