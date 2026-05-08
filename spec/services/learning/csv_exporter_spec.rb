require "rails_helper"

RSpec.describe Learning::CsvExporter do
  describe ".students_progress" do
    let(:customer) { create(:customer) }
    let!(:student) do
      create(:learning_student, customer: customer, name: "田中太郎",
             nickname: "たろう", total_effort_points: 30)
    end
    let!(:training_achieved) do
      create(:learning_student_training, customer: customer,
             learning_student: student, status: "achieved")
    end
    let!(:training_in_progress) do
      create(:learning_student_training, customer: customer,
             learning_student: student, status: "in_progress")
    end

    subject(:csv_string) { described_class.students_progress(customer) }

    it "CSVが生成されること" do
      expect(csv_string).to be_a(String)
    end

    it "ヘッダー行が含まれること" do
      expect(csv_string).to include("名前")
      expect(csv_string).to include("努力ポイント")
    end

    it "生徒のデータが含まれること" do
      expect(csv_string).to include("田中太郎")
      expect(csv_string).to include("たろう")
    end

    it "達成率が正しく計算されること" do
      # 2課題中1達成 = 50%
      expect(csv_string).to include("50.0")
    end

    it "努力ポイントが含まれること" do
      expect(csv_string).to include("30")
    end

    context "非アクティブな生徒がいる場合" do
      let!(:graduated_student) do
        create(:learning_student, customer: customer, name: "卒業生", status: "graduated")
      end

      it "非アクティブな生徒は含まれないこと" do
        expect(csv_string).not_to include("卒業生")
      end
    end
  end
end
