require 'rails_helper'

RSpec.describe Singing::DailyCoachMessageBuilder do
  def build_summary(attrs = {})
    Singing::JourneySummaryBuilder::Result.new(
      diagnosis_count:           attrs.fetch(:diagnosis_count, 5),
      best_score:                attrs.fetch(:best_score, 80),
      latest_score:              attrs.fetch(:latest_score, 75),
      streak_days:               attrs.fetch(:streak_days, 1),
      recent_growth_label:       attrs.fetch(:recent_growth_label, nil),
      recent_growth_delta_label: attrs.fetch(:recent_growth_delta_label, nil),
      has_diagnoses:             attrs.fetch(:has_diagnoses, true)
    )
  end

  describe '.call' do
    context 'customer が nil の場合' do
      it 'エラーにならず Result を返す' do
        result = described_class.call(nil, nil)
        expect(result).to be_a(Singing::DailyCoachMessageBuilder::Result)
        expect(result.message).to be_present
      end
    end

    context 'diagnostic なし（初回誘導）' do
      let(:customer) { build(:customer, singing_coach_personality: :gentle) }
      let(:summary)  { build_summary(has_diagnoses: false) }

      it 'no_diagnosis メッセージを返す' do
        result = described_class.call(customer, summary)
        expect(result.message).to be_present
        expect(result.coach_label).to eq('優しい先生')
        expect(result.coach_icon).to eq('🌿')
        expect(result.personality).to eq('gentle')
      end
    end

    context 'streak が 3 日以上' do
      let(:customer) { build(:customer, singing_coach_personality: :passionate) }
      let(:summary)  { build_summary(streak_days: 5) }

      it 'streak 系メッセージを返し、日数を含む' do
        result = described_class.call(customer, summary)
        expect(result.message).to include('5')
        expect(result.coach_icon).to eq('🔥')
      end
    end

    context 'リズムが伸びた' do
      let(:customer) { build(:customer, singing_coach_personality: :artist) }
      let(:summary)  { build_summary(recent_growth_label: 'リズム', streak_days: 1) }

      it 'rhythm_up コンテキストのメッセージを返す' do
        pool_messages = Singing::DailyCoachMessageBuilder::MESSAGES.dig(:rhythm_up, 'artist').map { |t|
          begin; t % [1]; rescue ArgumentError; t; end
        }
        result = described_class.call(customer, summary)
        expect(pool_messages).to include(result.message)
      end
    end

    context 'personality ごとにラベルが変わる' do
      let(:summary) { build_summary }

      it 'passionate は 熱血コーチ' do
        customer = build(:customer, singing_coach_personality: :passionate)
        expect(described_class.call(customer, summary).coach_label).to eq('熱血コーチ')
      end

      it 'gentle は 優しい先生' do
        customer = build(:customer, singing_coach_personality: :gentle)
        expect(described_class.call(customer, summary).coach_label).to eq('優しい先生')
      end

      it 'artist は アーティスト' do
        customer = build(:customer, singing_coach_personality: :artist)
        expect(described_class.call(customer, summary).coach_label).to eq('アーティスト')
      end
    end
  end
end
