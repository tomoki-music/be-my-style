require "rails_helper"

RSpec.describe Learning::StartGuideService do
  let(:customer) { create(:customer, domain_name: "learning") }
  let(:student) { create(:learning_student, customer: customer, main_part: "drums") }

  describe "#guide" do
    it "進捗ログの日数から7日間ガイドを作ること" do
      create(:learning_progress_log, customer: customer, learning_student: student, practiced_on: 2.days.ago.to_date)
      create(:learning_progress_log, customer: customer, learning_student: student, practiced_on: Date.current)

      guide = described_class.new(student).guide

      expect(guide.completed_days).to eq(2)
      expect(guide.remaining_days).to eq(5)
      expect(guide.progress_percent).to eq(29)
      expect(guide.current_step.day).to eq(3)
      expect(guide.steps.count(&:completed)).to eq(2)
    end

    it "7日分以上の記録がある場合は達成済みにすること" do
      7.times do |index|
        create(:learning_progress_log, customer: customer, learning_student: student,
                                      practiced_on: index.days.ago.to_date)
      end

      guide = described_class.new(student).guide

      expect(guide).to be_completed
      expect(guide.remaining_days).to eq(0)
      expect(guide.current_step.day).to eq(7)
    end
  end

  describe "#feedback" do
    it "前回との変化と次にやるべきことを返すこと" do
      create(:learning_progress_log, customer: customer, learning_student: student, practiced_on: Date.current)

      feedback = described_class.new(student).feedback

      expect(feedback.headline).to eq("少しずつでOK！積み重ねが大事")
      expect(feedback.change).to eq("前回より進捗が増えています")
      expect(feedback.next_action).to include("テンポ")
    end
  end

  describe "#badges" do
    it "進捗日数に応じた軽量バッジを返すこと" do
      3.times do |index|
        create(:learning_progress_log, customer: customer, learning_student: student,
                                      practiced_on: index.days.ago.to_date)
      end

      badges = described_class.new(student).badges

      expect(badges.find { |badge| badge.key == :first_completion }).to be_earned
      expect(badges.find { |badge| badge.key == :three_day_streak }).to be_earned
      expect(badges.find { |badge| badge.key == :week_complete }).not_to be_earned
    end
  end

  describe "#yesterday_summary" do
    it "昨日の練習タイトルを返すこと" do
      create(:learning_progress_log, customer: customer, learning_student: student,
                                    training_title: "リズム確認", practiced_on: Date.current - 1)

      expect(described_class.new(student).yesterday_summary).to eq("リズム確認")
    end
  end

  describe "#comeback?" do
    it "3日以上未実施なら復帰メッセージ対象にすること" do
      create(:learning_progress_log, customer: customer, learning_student: student,
                                    practiced_on: 3.days.ago.to_date)

      service = described_class.new(student)

      expect(service.idle_days).to eq(3)
      expect(service).to be_comeback
    end
  end
end
