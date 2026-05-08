require "rails_helper"

RSpec.describe Learning::OnboardingStatus do
  let(:routes) { Rails.application.routes.url_helpers }
  let(:customer) { create(:customer) }

  describe "#steps" do
    it "marks setup steps from existing learning data" do
      status = described_class.new(customer, routes: routes)

      expect(status.completed?).to eq(false)
      expect(status.completed_count).to eq(0)
      expect(status.steps.map(&:completed)).to eq([false, false, false, false, false])

      group = create(:learning_school_group, customer: customer)
      student = create(:learning_student, customer: customer, learning_school_group: group)
      training = create(:learning_student_training, customer: customer, learning_student: student)
      create(:learning_portal_access, learning_student: student)
      create(:learning_progress_log,
             customer: customer,
             learning_student: student,
             learning_student_training: training)

      completed_status = described_class.new(customer, routes: routes)

      expect(completed_status.completed?).to eq(true)
      expect(completed_status.completed_count).to eq(5)
      expect(completed_status.steps.map(&:completed)).to eq([true, true, true, true, true])
    end
  end
end
