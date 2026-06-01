require "rails_helper"

RSpec.describe Singing::ChallengeProgressBuilder do
  let(:customer) { create(:customer, domain_name: "singing") }

  describe ".call" do
    context "customer が nil のとき" do
      it "空配列を返す" do
        expect(described_class.call(nil)).to eq([])
      end
    end

    context "活動データがないとき" do
      it "全チャレンジの progress_ratio が 0" do
        progresses = described_class.call(customer)
        expect(progresses).not_to be_empty
        expect(progresses.map(&:progress_ratio)).to all(eq(0.0))
      end
    end

    describe "streak チャレンジ" do
      context "7 日連続診断したとき" do
        before do
          7.times { |i| create(:singing_diagnosis, :completed, customer: customer, created_at: i.days.ago) }
        end

        it "completed が true になる" do
          progress = described_class.call(customer).find { |p| p.challenge.id == :streak_7 }
          expect(progress.completed).to be true
        end

        it "current_value が 7 以上になる" do
          progress = described_class.call(customer).find { |p| p.challenge.id == :streak_7 }
          expect(progress.current_value).to be >= 7
        end
      end

      context "3 日しか診断していないとき" do
        before do
          3.times { |i| create(:singing_diagnosis, :completed, customer: customer, created_at: i.days.ago) }
        end

        it "completed が false になる" do
          progress = described_class.call(customer).find { |p| p.challenge.id == :streak_7 }
          expect(progress.completed).to be false
        end
      end
    end

    describe "diagnosis_count チャレンジ" do
      context "今週 5 回以上診断したとき" do
        before do
          5.times { create(:singing_diagnosis, :completed, customer: customer) }
        end

        it "completed が true になる" do
          progress = described_class.call(customer).find { |p| p.challenge.id == :diagnosis_5 }
          expect(progress.completed).to be true
        end
      end

      context "今週 2 回しか診断していないとき" do
        before do
          2.times { create(:singing_diagnosis, :completed, customer: customer) }
        end

        it "current_value が 2 になる" do
          progress = described_class.call(customer).find { |p| p.challenge.id == :diagnosis_5 }
          expect(progress.current_value).to eq(2)
        end
      end
    end

    describe "pitch_growth チャレンジ" do
      context "音程スコアが 3 点以上伸びたとき" do
        before do
          create(:singing_diagnosis, :completed, customer: customer, pitch_score: 70, created_at: 3.days.ago)
          create(:singing_diagnosis, :completed, customer: customer, pitch_score: 74)
        end

        it "completed が true になる" do
          progress = described_class.call(customer).find { |p| p.challenge.id == :pitch_growth }
          expect(progress.completed).to be true
        end
      end

      context "音程スコアが伸びていないとき" do
        before do
          create(:singing_diagnosis, :completed, customer: customer, pitch_score: 74, created_at: 3.days.ago)
          create(:singing_diagnosis, :completed, customer: customer, pitch_score: 72)
        end

        it "current_value が 0 になる" do
          progress = described_class.call(customer).find { |p| p.challenge.id == :pitch_growth }
          expect(progress.current_value).to eq(0)
        end
      end
    end

    describe "Progress DTO" do
      it "progress_percent が 0〜100 の範囲である" do
        progresses = described_class.call(customer)
        progresses.each do |p|
          expect(p.progress_percent).to be_between(0, 100)
        end
      end

      it "progress_label が '現在 / 目標' 形式" do
        progresses = described_class.call(customer)
        progresses.each do |p|
          expect(p.progress_label).to match(/\d+ \/ \d+/)
        end
      end
    end
  end
end
