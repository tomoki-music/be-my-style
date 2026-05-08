require "rails_helper"

RSpec.describe LearningPortalAccess, type: :model do
  describe ".record_access!" do
    let(:student) { create(:learning_student) }

    context "初回アクセス時" do
      it "アクセス記録が作成されること" do
        expect { described_class.record_access!(student) }
          .to change { described_class.count }.by(1)
      end

      it "streak_countが1になること" do
        described_class.record_access!(student)
        expect(described_class.last.streak_count).to eq(1)
      end
    end

    context "同日に2回アクセスした場合" do
      before { described_class.record_access!(student) }

      it "重複レコードが作成されないこと" do
        expect { described_class.record_access!(student) }
          .not_to change { described_class.count }
      end
    end

    context "前日にアクセス済みの場合" do
      before do
        create(:learning_portal_access,
               learning_student: student,
               accessed_on: Date.current - 1,
               streak_count: 3)
      end

      it "streak_countが前日+1になること" do
        described_class.record_access!(student)
        expect(described_class.find_by(accessed_on: Date.current).streak_count).to eq(4)
      end
    end

    context "7日連続アクセス時" do
      before do
        create(:learning_portal_access,
               learning_student: student,
               accessed_on: Date.current - 1,
               streak_count: 6)
      end

      it "streak_bonusポイントが付与されること" do
        expect { described_class.record_access!(student) }
          .to change { LearningEffortPoint.where(point_type: "streak_bonus").count }.by(1)
      end

      it "total_effort_pointsが加算されること" do
        described_class.record_access!(student)
        expect(student.reload.total_effort_points).to eq(10)
      end
    end
  end

  describe ".current_streak" do
    let(:student) { create(:learning_student) }

    it "今日アクセス済みの場合、streak_countを返すこと" do
      create(:learning_portal_access, learning_student: student, accessed_on: Date.current, streak_count: 5)
      expect(described_class.current_streak(student)).to eq(5)
    end

    it "今日未アクセスの場合、0を返すこと" do
      expect(described_class.current_streak(student)).to eq(0)
    end
  end
end
