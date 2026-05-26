require "rails_helper"

RSpec.describe Singing::RecapMovieCreationEligibilityService, type: :service do
  let!(:singing_domain) { Domain.find_or_create_by!(name: "singing") }
  let(:customer) { FactoryBot.create(:customer, domain_name: "singing") }

  subject(:result) { described_class.call(customer) }

  let(:current_year) { Time.current.year }

  def create_diagnoses(count, year: current_year)
    count.times.map do |i|
      FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed,
                        created_at: Time.zone.local(year, 6, 1) + i.days)
    end
  end

  describe ".call" do
    context "完了済み診断がない場合" do
      it "eligible が false であること" do
        expect(result.eligible?).to be false
      end

      it "reason が :no_diagnosis であること" do
        expect(result.reason).to eq(:no_diagnosis)
      end

      it "year が当年であること" do
        expect(result.year).to eq(current_year)
      end

      it "completed_diagnoses_count が 0 であること" do
        expect(result.completed_diagnoses_count).to eq(0)
      end

      it "required_diagnoses_count が 15 であること" do
        expect(result.required_diagnoses_count).to eq(15)
      end

      it "remaining_diagnoses_count が 15 であること" do
        expect(result.remaining_diagnoses_count).to eq(15)
      end

      it "period_label が当年の範囲を含むこと" do
        expect(result.period_label).to include("#{current_year}年1月1日")
        expect(result.period_label).to include("#{current_year}年12月31日")
      end

      it "適切なメッセージを返すこと" do
        expect(result.message).to include("歌声診断を完了すると")
      end
    end

    context "当年に完了済み診断が 1〜14 件の場合（not_enough_diagnoses）" do
      before { create_diagnoses(8) }

      it "eligible が false であること" do
        expect(result.eligible?).to be false
      end

      it "reason が :not_enough_diagnoses であること" do
        expect(result.reason).to eq(:not_enough_diagnoses)
      end

      it "year が当年であること" do
        expect(result.year).to eq(current_year)
      end

      it "completed_diagnoses_count が 8 であること" do
        expect(result.completed_diagnoses_count).to eq(8)
      end

      it "remaining_diagnoses_count が 7 であること" do
        expect(result.remaining_diagnoses_count).to eq(7)
      end

      it "required_diagnoses_count が 15 であること" do
        expect(result.required_diagnoses_count).to eq(15)
      end

      it "period_label が当年の範囲を含むこと" do
        expect(result.period_label).to include("#{current_year}年1月1日")
      end

      it "残り件数をメッセージに含むこと" do
        expect(result.message).to include("7件")
      end
    end

    context "当年に完了済み診断がちょうど 14 件の場合（残り 1 件）" do
      before { create_diagnoses(14) }

      it "eligible が false であること" do
        expect(result.eligible?).to be false
      end

      it "reason が :not_enough_diagnoses であること" do
        expect(result.reason).to eq(:not_enough_diagnoses)
      end

      it "remaining_diagnoses_count が 1 であること" do
        expect(result.remaining_diagnoses_count).to eq(1)
      end
    end

    context "当年に完了済み診断が 15 件以上ある場合（eligible）" do
      before { create_diagnoses(15) }

      it "eligible が true であること" do
        expect(result.eligible?).to be true
      end

      it "year が当年であること" do
        expect(result.year).to eq(current_year)
      end

      it "reason が :eligible であること" do
        expect(result.reason).to eq(:eligible)
      end

      it "completed_diagnoses_count が 15 以上であること" do
        expect(result.completed_diagnoses_count).to be >= 15
      end

      it "remaining_diagnoses_count が 0 であること" do
        expect(result.remaining_diagnoses_count).to eq(0)
      end

      it "required_diagnoses_count が 15 であること" do
        expect(result.required_diagnoses_count).to eq(15)
      end

      it "period_start が 1月1日であること" do
        expect(result.period_start).to eq(Date.new(current_year, 1, 1))
      end

      it "period_end が 12月31日であること" do
        expect(result.period_end).to eq(Date.new(current_year, 12, 31))
      end

      it "period_label が当年の範囲であること" do
        expect(result.period_label).to eq("#{current_year}年1月1日〜#{current_year}年12月31日")
      end
    end

    context "対象年外の診断は件数に含まれないこと" do
      before do
        FactoryBot.create_list(:singing_diagnosis, 15, customer: customer, status: :completed,
                               created_at: Time.zone.local(current_year - 1, 6, 1))
      end

      it "eligible が false であること（当年の診断がないため）" do
        expect(result.eligible?).to be false
      end

      it "completed_diagnoses_count が 0 であること" do
        expect(result.completed_diagnoses_count).to eq(0)
      end
    end

    context "既存 movie が pending の場合（15件以上ある）" do
      before do
        create_diagnoses(15)
        FactoryBot.create(:singing_generated_recap_movie,
                          customer: customer, year: current_year, status: :pending)
      end

      it "eligible が false であること" do
        expect(result.eligible?).to be false
      end

      it "reason が :already_pending であること" do
        expect(result.reason).to eq(:already_pending)
      end

      it "remaining_diagnoses_count が 0 であること" do
        expect(result.remaining_diagnoses_count).to eq(0)
      end
    end

    context "既存 movie が processing の場合（15件以上ある）" do
      before do
        create_diagnoses(15)
        FactoryBot.create(:singing_generated_recap_movie,
                          customer: customer, year: current_year, status: :processing)
      end

      it "eligible が false であること" do
        expect(result.eligible?).to be false
      end

      it "reason が :already_processing であること" do
        expect(result.reason).to eq(:already_processing)
      end
    end

    context "既存 movie が completed（reusable）の場合（15件以上ある）" do
      before do
        create_diagnoses(15)
        FactoryBot.create(:singing_generated_recap_movie, :completed,
                          customer: customer, year: current_year)
      end

      it "eligible が false であること" do
        expect(result.eligible?).to be false
      end

      it "reason が :already_completed であること" do
        expect(result.reason).to eq(:already_completed)
      end
    end

    context "既存 movie が failed の場合（15件以上ある）" do
      before do
        create_diagnoses(15)
        FactoryBot.create(:singing_generated_recap_movie, :failed,
                          customer: customer, year: current_year)
      end

      it "eligible が true であること" do
        expect(result.eligible?).to be true
      end

      it "reason が :retry_failed であること" do
        expect(result.reason).to eq(:retry_failed)
      end
    end

    context "既存 movie が expired の場合（15件以上ある）" do
      before do
        create_diagnoses(15)
        FactoryBot.create(:singing_generated_recap_movie, :expired,
                          customer: customer, year: current_year)
      end

      it "eligible が true であること" do
        expect(result.eligible?).to be true
      end

      it "reason が :retry_expired であること" do
        expect(result.reason).to eq(:retry_expired)
      end
    end

    context "year を明示的に指定した場合" do
      it "指定した年を対象にすること" do
        create_diagnoses(15, year: 2024)

        result = described_class.call(customer, year: 2024)

        expect(result.year).to eq(2024)
      end

      it "指定年の期間ラベルを返すこと" do
        create_diagnoses(15, year: 2024)

        result = described_class.call(customer, year: 2024)

        expect(result.period_label).to include("2024年1月1日")
      end
    end
  end
end
