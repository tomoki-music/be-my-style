class AddPortalFieldsToLearningStudents < ActiveRecord::Migration[6.1]
  class MigrationLearningStudent < ApplicationRecord
    self.table_name = "learning_students"
  end

  def change
    add_column :learning_students, :email, :string
    add_column :learning_students, :public_access_token, :string

    reversible do |dir|
      dir.up do
        MigrationLearningStudent.reset_column_information
        MigrationLearningStudent.find_each do |student|
          next if student.public_access_token.present?

          student.update_columns(public_access_token: generate_unique_token)
        end
      end
    end

    add_index :learning_students, [:customer_id, :email]
    add_index :learning_students, :public_access_token, unique: true
  end

  private

  def generate_unique_token
    loop do
      token = SecureRandom.urlsafe_base64(24)
      break token unless MigrationLearningStudent.exists?(public_access_token: token)
    end
  end
end
