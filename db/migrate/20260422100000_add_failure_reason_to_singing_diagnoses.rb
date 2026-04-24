class AddFailureReasonToSingingDiagnoses < ActiveRecord::Migration[6.1]
  def change
    add_column :singing_diagnoses, :failure_reason, :text
  end
end
