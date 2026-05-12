require "rails_helper"

RSpec.describe SingingDiagnoses::MonthlyAiChallenge do
  let(:customer) { FactoryBot.build(:customer) }

  def build_challenge(report)
    described_class.new(customer, growth_report: report).call
  end

  it "focus_key が pitch のとき音程チャレンジが返ること" do
    challenge = build_challenge(focus_key: "pitch", focus_label: "音程", has_enough_data: true)

    expect(challenge[:title]).to eq "音程安定チャレンジ"
    expect(challenge[:target_key]).to eq "pitch"
    expect(challenge[:target_label]).to eq "音程"
    expect(challenge[:source]).to eq "monthly_growth_report"
  end

  it "focus_key が rhythm のときリズムチャレンジが返ること" do
    challenge = build_challenge(focus_key: "rhythm", focus_label: "リズム", has_enough_data: true)

    expect(challenge[:title]).to eq "リズム安定チャレンジ"
    expect(challenge[:practice_steps]).to include("メトロノームを60〜80BPMに設定する")
  end

  it "focus_key が expression のとき表現力チャレンジが返ること" do
    challenge = build_challenge(focus_key: "expression", focus_label: "表現", has_enough_data: true)

    expect(challenge[:title]).to eq "表現力アップチャレンジ"
    expect(challenge[:target_key]).to eq "expression"
  end

  it "has_enough_data false のとき fallback チャレンジが返ること" do
    challenge = build_challenge(focus_key: "rhythm", focus_label: "リズム", has_enough_data: false)

    expect(challenge[:title]).to eq "まずは診断を積み上げよう"
    expect(challenge[:target_key]).to eq "habit"
    expect(challenge[:source]).to eq "fallback"
  end

  it "practice_steps が配列で返ること" do
    challenge = build_challenge(focus_key: "pitch", focus_label: "音程", has_enough_data: true)

    expect(challenge[:practice_steps]).to be_an(Array)
    expect(challenge[:practice_steps].size).to eq 3
  end

  it "nilや想定外 focus_key でも落ちないこと" do
    nil_focus = build_challenge(focus_key: nil, focus_label: nil, has_enough_data: true)
    unknown_focus = build_challenge(focus_key: "tone", focus_label: "音色", has_enough_data: true)

    expect(nil_focus[:title]).to eq "まずは診断を積み上げよう"
    expect(unknown_focus[:title]).to eq "まずは診断を積み上げよう"
  end

  it "available が true で返ること" do
    challenge = build_challenge(focus_key: "rhythm", focus_label: "リズム", has_enough_data: true)

    expect(challenge[:available]).to eq true
  end
end
