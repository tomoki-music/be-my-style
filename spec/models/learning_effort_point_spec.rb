require "rails_helper"

RSpec.describe LearningEffortPoint, type: :model do
  describe "validations" do
    it "有効なレコードが作成できること" do
      record = build(:learning_effort_point)
      expect(record).to be_valid
    end

    it "point_typeが不正な場合は無効であること" do
      record = build(:learning_effort_point, point_type: "invalid_type")
      expect(record).not_to be_valid
    end

    it "earned_onがない場合は無効であること" do
      record = build(:learning_effort_point, earned_on: nil)
      expect(record).not_to be_valid
    end
  end

  describe "scopes" do
    let!(:today_point) { create(:learning_effort_point, earned_on: Date.current) }
    let!(:old_point)   { create(:learning_effort_point, earned_on: 2.months.ago) }

    it "this_month returns only current month records" do
      expect(described_class.this_month).to include(today_point)
      expect(described_class.this_month).not_to include(old_point)
    end

    it "this_week returns only current week records" do
      expect(described_class.this_week).to include(today_point)
    end
  end
end
