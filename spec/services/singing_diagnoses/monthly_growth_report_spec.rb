require "rails_helper"

RSpec.describe SingingDiagnoses::MonthlyGrowthReport do
  let(:customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let(:reference_time) { Time.zone.local(2026, 5, 12, 12, 0, 0) }

  def create_completed(created_at:, overall:, pitch:, rhythm:, expression:)
    FactoryBot.create(
      :singing_diagnosis,
      :completed,
      customer: customer,
      overall_score: overall,
      pitch_score: pitch,
      rhythm_score: rhythm,
      expression_score: expression,
      created_at: created_at,
      diagnosed_at: created_at
    )
  end

  def report
    described_class.new(customer, reference_time: reference_time).call
  end

  it "今月/前月の診断件数が正しく出ること" do
    create_completed(created_at: reference_time.beginning_of_month + 1.day, overall: 80, pitch: 70, rhythm: 75, expression: 78)
    create_completed(created_at: reference_time.beginning_of_month + 2.days, overall: 90, pitch: 80, rhythm: 85, expression: 88)
    create_completed(created_at: reference_time.prev_month.beginning_of_month + 1.day, overall: 75, pitch: 65, rhythm: 70, expression: 73)
    FactoryBot.create(:singing_diagnosis, customer: customer, status: :failed, created_at: reference_time.beginning_of_month + 3.days)

    expect(report[:current_month_count]).to eq 2
    expect(report[:previous_month_count]).to eq 1
  end

  it "overall_delta が平均差分で出ること" do
    create_completed(created_at: reference_time.beginning_of_month + 1.day, overall: 80, pitch: 80, rhythm: 70, expression: 70)
    create_completed(created_at: reference_time.beginning_of_month + 2.days, overall: 90, pitch: 80, rhythm: 70, expression: 70)
    create_completed(created_at: reference_time.prev_month.beginning_of_month + 1.day, overall: 75, pitch: 70, rhythm: 70, expression: 70)

    expect(report[:overall_delta]).to eq 10
  end

  it "best_growth_key / label / delta が正しく出ること" do
    create_completed(created_at: reference_time.beginning_of_month + 1.day, overall: 80, pitch: 85, rhythm: 72, expression: 74)
    create_completed(created_at: reference_time.prev_month.beginning_of_month + 1.day, overall: 70, pitch: 70, rhythm: 70, expression: 70)

    expect(report[:best_growth_key]).to eq "pitch"
    expect(report[:best_growth_label]).to eq "音程"
    expect(report[:best_growth_delta]).to eq 15
  end

  it "focus_key / label が今月平均の最低項目になること" do
    create_completed(created_at: reference_time.beginning_of_month + 1.day, overall: 80, pitch: 82, rhythm: 60, expression: 78)
    create_completed(created_at: reference_time.prev_month.beginning_of_month + 1.day, overall: 70, pitch: 75, rhythm: 65, expression: 76)

    expect(report[:focus_key]).to eq "rhythm"
    expect(report[:focus_label]).to eq "リズム"
    expect(report[:focus_message]).to eq "今月はリズム安定を重点的に練習しましょう。"
  end

  it "今月データなしで落ちず has_enough_data が false になること" do
    create_completed(created_at: reference_time.prev_month.beginning_of_month + 1.day, overall: 70, pitch: 75, rhythm: 65, expression: 76)

    expect(report[:current_month_count]).to eq 0
    expect(report[:has_enough_data]).to eq false
  end

  it "前月データなしで落ちず has_enough_data が false になること" do
    create_completed(created_at: reference_time.beginning_of_month + 1.day, overall: 80, pitch: 82, rhythm: 60, expression: 78)

    expect(report[:previous_month_count]).to eq 0
    expect(report[:has_enough_data]).to eq false
  end

  it "今月と前月に診断がある場合 has_enough_data が true になること" do
    create_completed(created_at: reference_time.beginning_of_month + 1.day, overall: 80, pitch: 82, rhythm: 60, expression: 78)
    create_completed(created_at: reference_time.prev_month.beginning_of_month + 1.day, overall: 70, pitch: 75, rhythm: 65, expression: 76)

    expect(report[:has_enough_data]).to eq true
  end

  it "nilスコアでも落ちないこと" do
    create_completed(created_at: reference_time.beginning_of_month + 1.day, overall: nil, pitch: nil, rhythm: nil, expression: nil)
    create_completed(created_at: reference_time.prev_month.beginning_of_month + 1.day, overall: nil, pitch: nil, rhythm: nil, expression: nil)

    expect(report[:overall_delta]).to eq 0
    expect(report[:best_growth_key]).to eq "pitch"
    expect(report[:focus_key]).to eq "pitch"
    expect(report[:has_enough_data]).to eq true
  end
end
