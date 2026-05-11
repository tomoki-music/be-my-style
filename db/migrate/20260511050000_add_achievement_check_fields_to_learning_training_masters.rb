class AddAchievementCheckFieldsToLearningTrainingMasters < ActiveRecord::Migration[6.1]
  def change
    add_column :learning_training_masters, :check_method, :text
    add_column :learning_training_masters, :judge_type, :string, default: "self", null: false
    add_index :learning_training_masters, :judge_type
  end
end
