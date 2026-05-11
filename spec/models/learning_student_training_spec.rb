require "rails_helper"

RSpec.describe LearningStudentTraining, type: :model do
  it "作成時に今週の課題を自動生成すること" do
    training = create(:learning_student_training, title: "腹式呼吸トレーニング", description: "息を長く吐く")

    assignment = training.learning_assignments.first
    expect(assignment.title).to eq("【今週の課題】腹式呼吸トレーニング")
    expect(assignment.description).to include("今週は以下のトレーニングに取り組みましょう！")
    expect(assignment.description).to include("息を長く吐く")
    expect(assignment.due_on).to eq(7.days.from_now.to_date)
    expect(assignment.status).to eq("pending")
  end

  it "同一割当トレーニングの未完了課題があれば重複作成しないこと" do
    training = create(:learning_student_training)

    expect {
      training.send(:create_weekly_assignment)
    }.not_to change(LearningAssignment, :count)
  end
end
