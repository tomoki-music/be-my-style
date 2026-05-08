require "rails_helper"

RSpec.describe Learning::WeeklyReviewService do
  let(:customer) { create(:customer, domain_name: "learning") }
  let(:students) do
    [
      create(:learning_student, customer: customer, name: "今週多い"),
      create(:learning_student, customer: customer, name: "伸びた"),
      create(:learning_student, customer: customer, name: "停滞")
    ]
  end

  describe "#build" do
    it "今週の上位・伸びた生徒・停滞生徒を軽量集計すること" do
      active_student, growth_student, stagnant_student = students

      3.times do
        create(:learning_progress_log, customer: customer, learning_student: active_student,
                                      practiced_on: Date.current)
      end
      2.times do
        create(:learning_progress_log, customer: customer, learning_student: growth_student,
                                      practiced_on: Date.current)
      end
      create(:learning_progress_log, customer: customer, learning_student: stagnant_student,
                                    practiced_on: 4.days.ago.to_date)
      create(:learning_progress_log, customer: customer, learning_student: stagnant_student,
                                    practiced_on: 8.days.ago.to_date)

      review = described_class.new(customer, students: students).build

      expect(review.top_students.first.student).to eq(active_student)
      expect(review.top_students.first.count).to eq(3)
      expect(review.growth_students.map(&:student)).to include(active_student, growth_student)
      expect(review.stagnant_students.map(&:student)).to include(stagnant_student)
      expect(review.stagnant_students.find { |item| item.student == stagnant_student }.status_label).to eq("停滞中")
      expect(review.stagnant_students.find { |item| item.student == stagnant_student }.template).to include("最近どう？")
    end

    it "記録がない生徒も介入対象に含めること" do
      review = described_class.new(customer, students: students).build

      expect(review.stagnant_students.map(&:student)).to match_array(students)
      expect(review.stagnant_students.first.last_practiced_on).to be_nil
      expect(review.stagnant_students.first.status_label).to eq("記録なし")
    end
  end
end
