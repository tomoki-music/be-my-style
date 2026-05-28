require 'rails_helper'

RSpec.describe Singing::DailyMissionSelector do
  describe '.call' do
    context 'diagnosis が nil の場合' do
      it 'no_diagnosis カテゴリのミッションを返す' do
        result = described_class.call(nil)
        expect(result).to be_a(Singing::DailyMissionSelector::Result)
        expect(result.title).to be_present
        expect(result.body).to be_present
        pool_titles = Singing::DailyMissionSelector::MISSIONS[:no_diagnosis].map { |m| m[:title] }
        expect(pool_titles).to include(result.title)
      end
    end

    context 'rhythm_score が閾値以下の diagnosis' do
      let(:diagnosis) do
        build(:singing_diagnosis, :completed,
              rhythm_score: 55, pitch_score: 75, expression_score: 78)
      end

      it 'rhythm カテゴリのミッションを返す' do
        result = described_class.call(diagnosis)
        pool_titles = Singing::DailyMissionSelector::MISSIONS[:rhythm].map { |m| m[:title] }
        expect(pool_titles).to include(result.title)
      end
    end

    context 'pitch_score が最も低い diagnosis' do
      let(:diagnosis) do
        build(:singing_diagnosis, :completed,
              rhythm_score: 75, pitch_score: 58, expression_score: 80)
      end

      it 'pitch カテゴリのミッションを返す' do
        result = described_class.call(diagnosis)
        pool_titles = Singing::DailyMissionSelector::MISSIONS[:pitch].map { |m| m[:title] }
        expect(pool_titles).to include(result.title)
      end
    end

    context '全スコアが閾値以上の diagnosis' do
      let(:diagnosis) do
        build(:singing_diagnosis, :completed,
              rhythm_score: 75, pitch_score: 72, expression_score: 80)
      end

      it 'general カテゴリのミッションを返す' do
        result = described_class.call(diagnosis)
        pool_titles = Singing::DailyMissionSelector::MISSIONS[:general].map { |m| m[:title] }
        expect(pool_titles).to include(result.title)
      end
    end

    context 'スコアが nil を含む diagnosis' do
      let(:diagnosis) do
        build(:singing_diagnosis, :completed,
              rhythm_score: nil, pitch_score: nil, expression_score: nil)
      end

      it 'エラーにならず general ミッションを返す' do
        result = described_class.call(diagnosis)
        expect(result.title).to be_present
      end
    end
  end
end
