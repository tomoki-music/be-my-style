require "rails_helper"

RSpec.describe SingingDiagnoses::NextPracticeMenu do
  def build_diagnosis(scores = {})
    FactoryBot.build(
      :singing_diagnosis,
      :completed,
      {
        overall_score: 76,
        pitch_score: 82,
        rhythm_score: 82,
        expression_score: 82
      }.merge(scores)
    )
  end

  it "pitch_score が低い場合、音程系メニューを返すこと" do
    menu = described_class.new(build_diagnosis(pitch_score: 62)).call

    expect(menu.first[:title]).to eq "音程安定トレーニング"
  end

  it "rhythm_score が低い場合、リズム系メニューを返すこと" do
    menu = described_class.new(build_diagnosis(rhythm_score: 63)).call

    expect(menu.first[:title]).to eq "リズムキープ練習"
  end

  it "expression_score が低い場合、表現系メニューを返すこと" do
    menu = described_class.new(build_diagnosis(expression_score: 64)).call

    expect(menu.first[:title]).to eq "表現力アップ練習"
  end

  it "overall_score が高い場合、上級チャレンジ系メニューを返すこと" do
    menu = described_class.new(build_diagnosis(overall_score: 90)).call

    expect(menu.map { |item| item[:title] }).to include "次のステージ：楽曲表現チャレンジ"
  end

  it "スコアが nil の場合でも落ちないこと" do
    menu = described_class.new(build_diagnosis(overall_score: nil, pitch_score: nil, rhythm_score: nil, expression_score: nil)).call

    expect(menu).to be_present
    expect(menu.first[:title]).to eq "基礎バランス確認メニュー"
  end

  it "最大表示件数が多すぎないこと" do
    menu = described_class.new(build_diagnosis(overall_score: 95, pitch_score: 60, rhythm_score: 60, expression_score: 60)).call

    expect(menu.size).to be <= 3
  end
end
