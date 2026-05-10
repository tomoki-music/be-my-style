require "rails_helper"

RSpec.describe LearningStudent, type: :model do
  describe "#learning_streak_days" do
    let(:student) { create(:learning_student) }

    it "練習記録がない場合は0を返すこと" do
      expect(student.learning_streak_days).to eq(0)
    end

    it "今日の記録から連続日数を数えること" do
      create_progress_on(Date.current)
      create_progress_on(Date.current - 1)
      create_progress_on(Date.current - 2)

      expect(student.learning_streak_days).to eq(3)
    end

    it "今日未記録でも昨日までの継続を数えること" do
      create_progress_on(Date.current - 1)
      create_progress_on(Date.current - 2)

      expect(student.learning_streak_days).to eq(2)
    end

    it "日付重複があっても重複カウントしないこと" do
      create_progress_on(Date.current)
      create_progress_on(Date.current)
      create_progress_on(Date.current - 1)

      expect(student.learning_streak_days).to eq(2)
    end

    it "途中で途切れた日付より前は数えないこと" do
      create_progress_on(Date.current)
      create_progress_on(Date.current - 2)

      expect(student.learning_streak_days).to eq(1)
    end

    def create_progress_on(date)
      create(:learning_progress_log,
             customer: student.customer,
             learning_student: student,
             practiced_on: date)
    end
  end
end
