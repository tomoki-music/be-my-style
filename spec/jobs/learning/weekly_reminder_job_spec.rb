require "rails_helper"

RSpec.describe Learning::WeeklyReminderJob, type: :job do
  describe "#perform" do
    it "未実施日数に応じたリマインドをログ出力すること" do
      teacher = create(:customer, domain_name: "learning")
      student = create(:learning_student, customer: teacher)
      create(:learning_progress_log, customer: teacher, learning_student: student,
                                    practiced_on: 3.days.ago.to_date)

      allow(Rails.logger).to receive(:info)

      described_class.perform_now

      expect(Rails.logger).to have_received(:info).with(
        a_string_including("student_id=#{student.id}", "stage=3", "ここで戻ると差がつきます")
      )
    end
  end
end
