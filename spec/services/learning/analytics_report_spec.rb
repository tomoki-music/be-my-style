require "rails_helper"

RSpec.describe Learning::AnalyticsReport do
  let(:reference_time) { Time.zone.local(2026, 5, 6, 12, 0, 0) }
  let(:customer) { create(:customer, domain_name: "learning") }
  let(:other_customer) { create(:customer, domain_name: "learning") }
  let(:student) { create(:learning_student, customer: customer, name: "山田太郎") }
  let(:other_student) { create(:learning_student, customer: other_customer, name: "他校生徒") }

  subject(:report) { described_class.new(customer, period: "this_week", reference_time: reference_time) }

  describe "#summary" do
    it "今週の提出率を算出できること" do
      create(:learning_assignment, customer: customer, learning_student: student,
                                   status: "completed", completed_at: reference_time)
      create(:learning_assignment, customer: customer, learning_student: student,
                                   status: "pending", created_at: reference_time)

      expect(report.summary.assignment_submission_rate).to eq(50)
      expect(report.summary.unsubmitted_count).to eq(1)
    end

    it "LINE反応率を算出できること" do
      create(:learning_notification_log, customer: customer, learning_student: student,
                                         delivery_channel: "line", status: "sent",
                                         generated_at: reference_time,
                                         reaction_received: true, reacted_at: reference_time)
      create(:learning_notification_log, customer: customer, learning_student: student,
                                         delivery_channel: "line", status: "sent",
                                         generated_at: reference_time,
                                         reaction_received: false, reacted_at: nil)

      expect(report.summary.line_reaction_rate).to eq(50)
      expect(report.summary.line_reaction_count).to eq(1)
      expect(report.summary.line_sent_count).to eq(2)
    end

    it "練習記録数を算出できること" do
      create(:learning_progress_log, customer: customer, learning_student: student,
                                     practiced_on: reference_time.to_date)
      create(:learning_progress_log, customer: customer, learning_student: student,
                                     practiced_on: 2.weeks.ago(reference_time).to_date)

      expect(report.summary.progress_log_count).to eq(1)
    end

    it "他顧問のデータを含めないこと" do
      create(:learning_assignment, customer: other_customer, learning_student: other_student,
                                   status: "completed", completed_at: reference_time)
      create(:learning_notification_log, customer: other_customer, learning_student: other_student,
                                         delivery_channel: "line", status: "sent",
                                         generated_at: reference_time,
                                         reaction_received: true, reacted_at: reference_time)
      create(:learning_progress_log, customer: other_customer, learning_student: other_student,
                                     practiced_on: reference_time.to_date)

      expect(report.summary.assignment_count).to eq(0)
      expect(report.summary.line_sent_count).to eq(0)
      expect(report.summary.progress_log_count).to eq(0)
    end

    it "データなしでも0を返すこと" do
      expect(report.summary.assignment_submission_rate).to eq(0)
      expect(report.summary.line_reaction_rate).to eq(0)
      expect(report.summary.progress_log_count).to eq(0)
    end
  end

  describe "#student_summaries" do
    it "生徒別提出率を算出できること" do
      create(:learning_assignment, customer: customer, learning_student: student,
                                   status: "completed", completed_at: reference_time)
      create(:learning_assignment, customer: customer, learning_student: student,
                                   status: "pending", created_at: reference_time)
      create(:learning_notification_log, customer: customer, learning_student: student,
                                         delivery_channel: "line", status: "sent",
                                         generated_at: reference_time,
                                         reaction_received: true, reacted_at: reference_time)

      summary = report.student_summaries.first

      expect(summary.student).to eq(student)
      expect(summary.submission_rate).to eq(50)
      expect(summary.reaction_rate).to eq(100)
      expect(summary.status_label).to eq("様子見")
    end

    it "7日以上未反応を要フォローにすること" do
      create(:learning_assignment, customer: customer, learning_student: student,
                                   status: "completed", completed_at: reference_time)
      create(:learning_notification_log, customer: customer, learning_student: student,
                                         delivery_channel: "line", status: "sent",
                                         generated_at: reference_time,
                                         reaction_received: true,
                                         reacted_at: 8.days.ago(reference_time))

      summary = report.student_summaries.first

      expect(summary.status_label).to eq("要フォロー")
      expect(report.summary.inactive_student_count).to eq(1)
    end

    it "提出率70%以上かつ7日以内に反応があれば順調にすること" do
      create(:learning_assignment, customer: customer, learning_student: student,
                                   status: "completed", completed_at: reference_time)
      create(:learning_notification_log, customer: customer, learning_student: student,
                                         delivery_channel: "line", status: "sent",
                                         generated_at: reference_time,
                                         reaction_received: true,
                                         reacted_at: 2.days.ago(reference_time))

      expect(report.student_summaries.first.status_label).to eq("順調")
    end
  end

  describe "#assignment_summaries" do
    it "課題別完了率を算出できること" do
      group_key = "live-basic"
      create(:learning_assignment, customer: customer, learning_student: student,
                                   title: "ライブ前基礎練習", status: "completed",
                                   completed_at: reference_time, assignment_group_key: group_key)
      create(:learning_assignment, customer: customer, learning_student: student,
                                   title: "ライブ前基礎練習", status: "pending",
                                   created_at: reference_time, assignment_group_key: group_key)

      summary = report.assignment_summaries.first

      expect(summary.title).to eq("ライブ前基礎練習")
      expect(summary.completion_rate).to eq(50)
      expect(summary.completed_count).to eq(1)
      expect(summary.total_count).to eq(2)
    end
  end

  describe "#period_label" do
    it "periodに応じて期間を切り替えること" do
      last_week_report = described_class.new(customer, period: "last_week", reference_time: reference_time)
      create(:learning_progress_log, customer: customer, learning_student: student,
                                     practiced_on: 1.week.ago(reference_time).to_date)

      expect(last_week_report.period_label).to eq("先週")
      expect(last_week_report.summary.progress_log_count).to eq(1)
    end
  end
end
