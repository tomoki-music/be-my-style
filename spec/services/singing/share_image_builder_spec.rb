require 'rails_helper'

RSpec.describe Singing::ShareImageBuilder do
  let(:growth_type_result) do
    Singing::GrowthTypeAnalyzer::Result.new(
      type_key: "emotional_singer", label: "Emotional Singer", icon: "✨", description: ""
    )
  end

  def stub_wrapped(customer, attrs = {})
    allow(Singing::MonthlyWrappedBuilder).to receive(:call).with(customer, year: 2026, month: 5).and_return(
      Singing::MonthlyWrappedBuilder::Result.new(
        year:                attrs.fetch(:year, 2026),
        month:               attrs.fetch(:month, 5),
        diagnosis_count:     attrs.fetch(:diagnosis_count, 0),
        active_days_count:   attrs.fetch(:active_days_count, 0),
        monthly_xp:          attrs.fetch(:monthly_xp, 0),
        growth_type:         attrs.fetch(:growth_type, nil),
        singer_rank:         attrs.fetch(:singer_rank, nil),
        most_improved_label: attrs.fetch(:most_improved_label, nil),
        most_improved_delta: attrs.fetch(:most_improved_delta, nil),
        wrapped_message:     attrs.fetch(:wrapped_message, nil),
        coach_reflection:    attrs.fetch(:coach_reflection, nil),
        has_wrapped:         attrs.fetch(:has_wrapped, false)
      )
    )
  end

  describe '.call' do
    context 'customer が nil の場合' do
      it '落ちずに空の ShareCard を返す' do
        result = described_class.call(nil, year: 2026, month: 5)
        expect(result).to be_a(Singing::ShareImageBuilder::ShareCard)
        expect(result.has_data).to eq false
        expect(result.diagnosis_count).to eq 0
      end
    end

    context '診断データがない customer の場合' do
      let(:customer) { build(:customer, singing_xp: 0) }

      before do
        stub_wrapped(customer)
        allow(Singing::GrowthTypeAnalyzer).to receive(:call).and_return(growth_type_result)
        allow(Singing::StreakCalculator).to receive(:call).and_return(0)
        allow(customer).to receive(:has_feature?).and_return(false)
        allow(customer).to receive(:singer_rank).and_return(nil)
      end

      it 'has_data が false になる' do
        result = described_class.call(customer, year: 2026, month: 5)
        expect(result.has_data).to eq false
      end
    end

    context '診断データがある customer の場合' do
      let(:customer) { build(:customer, singing_xp: 150) }

      before do
        stub_wrapped(customer,
          diagnosis_count:     8,
          active_days_count:   6,
          monthly_xp:          400,
          growth_type:         growth_type_result,
          most_improved_label: "表現力",
          most_improved_delta: 12,
          wrapped_message:     "今月も歌い続けました。",
          has_wrapped:         true
        )
        allow(Singing::StreakCalculator).to receive(:call).and_return(5)
        allow(customer).to receive(:has_feature?).with(:singing_monthly_wrapped_share_image).and_return(false)
        allow(customer).to receive(:singer_rank).and_return(nil)
      end

      it 'ShareCard を返す' do
        result = described_class.call(customer, year: 2026, month: 5)
        expect(result).to be_a(Singing::ShareImageBuilder::ShareCard)
      end

      it 'has_data が true になる' do
        result = described_class.call(customer, year: 2026, month: 5)
        expect(result.has_data).to eq true
      end

      it '診断回数が反映される' do
        result = described_class.call(customer, year: 2026, month: 5)
        expect(result.diagnosis_count).to eq 8
      end

      it 'streak が反映される' do
        result = described_class.call(customer, year: 2026, month: 5)
        expect(result.streak).to eq 5
      end

      it 'most_improved_label / delta が反映される' do
        result = described_class.call(customer, year: 2026, month: 5)
        expect(result.most_improved_label).to eq "表現力"
        expect(result.most_improved_delta).to eq 12
      end

      it 'growth_type_label が反映される' do
        result = described_class.call(customer, year: 2026, month: 5)
        expect(result.growth_type_label).to eq "Emotional Singer"
      end

      context 'free プランの場合（singing_monthly_wrapped_share_image 未解放）' do
        it 'coach_reflection が nil になる' do
          result = described_class.call(customer, year: 2026, month: 5)
          expect(result.coach_reflection).to be_nil
          expect(result.has_premium_features).to eq false
        end
      end

      context 'core / premium プランの場合（singing_monthly_wrapped_share_image 解放済み）' do
        before do
          allow(customer).to receive(:has_feature?).with(:singing_monthly_wrapped_share_image).and_return(true)
          stub_wrapped(customer,
            diagnosis_count:     8,
            active_days_count:   6,
            monthly_xp:          400,
            growth_type:         growth_type_result,
            most_improved_label: "表現力",
            most_improved_delta: 12,
            wrapped_message:     "今月も歌い続けました。",
            coach_reflection:    "声に感情が宿ってきた。",
            has_wrapped:         true
          )
        end

        it 'has_premium_features が true になる' do
          result = described_class.call(customer, year: 2026, month: 5)
          expect(result.has_premium_features).to eq true
        end

        it 'coach_reflection が含まれる' do
          result = described_class.call(customer, year: 2026, month: 5)
          expect(result.coach_reflection).to eq "声に感情が宿ってきた。"
        end
      end
    end

    context 'MonthlyWrappedBuilder が growth_type を返さない場合' do
      let(:customer) { build(:customer, singing_xp: 50) }

      before do
        stub_wrapped(customer,
          diagnosis_count: 2, active_days_count: 2, monthly_xp: 100,
          growth_type: nil, wrapped_message: "今月も歌いました。",
          has_wrapped: true
        )
        allow(Singing::GrowthTypeAnalyzer).to receive(:call).with(customer).and_return(
          Singing::GrowthTypeAnalyzer::Result.new(
            type_key: "groove_builder", label: "Groove Builder", icon: "🎵", description: ""
          )
        )
        allow(Singing::StreakCalculator).to receive(:call).and_return(1)
        allow(customer).to receive(:has_feature?).and_return(false)
        allow(customer).to receive(:singer_rank).and_return(nil)
      end

      it 'GrowthTypeAnalyzer をフォールバックとして使う' do
        result = described_class.call(customer, year: 2026, month: 5)
        expect(result.growth_type_label).to eq "Groove Builder"
      end
    end
  end
end
