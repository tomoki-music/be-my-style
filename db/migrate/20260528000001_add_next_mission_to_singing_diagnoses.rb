class AddNextMissionToSingingDiagnoses < ActiveRecord::Migration[6.1]
  def change
    add_column :singing_diagnoses, :next_mission_title, :string, limit: 100
    add_column :singing_diagnoses, :next_mission_body, :string, limit: 300
  end
end
