require "rails_helper"

RSpec.describe LearningAssignment, type: :model do
  it "pending / in_progress / completed を有効なstatusとして扱うこと" do
    described_class::STATUSES.each do |status|
      assignment = build(:learning_assignment, status: status)

      expect(assignment).to be_valid
    end
  end

  it "未定義statusは無効にすること" do
    assignment = build(:learning_assignment, status: "archived")

    expect(assignment).not_to be_valid
    expect(assignment.errors[:status]).to be_present
  end

  it "他顧問の生徒は紐付けられないこと" do
    teacher = create(:customer, domain_name: "learning", confirmed_at: Time.current)
    other_teacher = create(:customer, domain_name: "learning", confirmed_at: Time.current)
    other_student = create(:learning_student, customer: other_teacher)
    assignment = build(:learning_assignment, customer: teacher, learning_student: other_student)

    expect(assignment).not_to be_valid
    expect(assignment.errors[:learning_student]).to be_present
  end

  it "complete!で完了日時を保存すること" do
    assignment = create(:learning_assignment)
    completed_at = Time.zone.local(2026, 5, 20, 12, 0, 0)

    assignment.complete!(time: completed_at)

    expect(assignment.reload.status).to eq("completed")
    expect(assignment.completed_at).to eq(completed_at)
  end
end
