require "rails_helper"

RSpec.describe Learning::OnboardingChecklist do
  let(:routes) { Rails.application.routes.url_helpers }
  let(:teacher) { create(:customer, domain_name: "learning") }
  let(:checklist) { described_class.new(teacher, routes: routes) }

  def item(key)
    checklist.items.find { |entry| entry.key == key }
  end

  it "marks checklist items incomplete when students are not registered" do
    expect(item(:students_registered)).not_to be_completed
    expect(item(:line_connected)).not_to be_completed
    expect(item(:assignment_created)).not_to be_completed
  end

  it "marks students_registered complete when an active student exists" do
    create(:learning_student, customer: teacher)

    expect(item(:students_registered)).to be_completed
  end

  it "marks line_connected complete when a connected LINE student exists" do
    student = create(:learning_student, customer: teacher)
    create(:learning_line_connection, customer: teacher, learning_student: student, status: "connected")

    expect(item(:line_connected)).to be_completed
  end

  it "marks assignment_created complete when an assignment exists" do
    student = create(:learning_student, customer: teacher)
    create(:learning_assignment, customer: teacher, learning_student: student)

    expect(item(:assignment_created)).to be_completed
  end

  it "marks auto_reminder_enabled complete when auto reminder is enabled" do
    create(:learning_notification_setting, customer: teacher, auto_reminder_enabled: true)

    expect(item(:auto_reminder_enabled)).to be_completed
  end
end
