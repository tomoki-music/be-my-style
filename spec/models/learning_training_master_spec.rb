require "rails_helper"

RSpec.describe LearningTrainingMaster, type: :model do
  it "self / peer / teacher を確認者として扱うこと" do
    described_class::JUDGE_TYPES.each do |judge_type|
      master = build(:learning_training_master, judge_type: judge_type)

      expect(master).to be_valid
    end
  end

  it "未定義の確認者は無効にすること" do
    master = build(:learning_training_master, judge_type: "parent")

    expect(master).not_to be_valid
    expect(master.errors[:judge_type]).to be_present
  end

  it "確認者ラベルを返すこと" do
    expect(build(:learning_training_master, judge_type: "self").judge_type_label).to eq("自分で確認")
    expect(build(:learning_training_master, judge_type: "peer").judge_type_label).to eq("生徒同士で確認")
    expect(build(:learning_training_master, judge_type: "teacher").judge_type_label).to eq("先生が確認")
  end

  it "確認者未指定時は自分で確認にすること" do
    master = build(:learning_training_master, judge_type: nil)

    master.validate

    expect(master.judge_type).to eq("self")
  end
end
