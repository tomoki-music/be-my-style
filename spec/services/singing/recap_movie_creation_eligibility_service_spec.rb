require "rails_helper"

RSpec.describe Singing::RecapMovieCreationEligibilityService, type: :service do
  let!(:singing_domain) { Domain.find_or_create_by!(name: "singing") }
  let(:customer) { FactoryBot.create(:customer, domain_name: "singing") }

  subject(:result) { described_class.call(customer) }

  describe ".call" do
    context "完了済み診断がない場合" do
      it "eligible が false であること" do
        expect(result.eligible?).to be false
      end

      it "reason が :no_diagnosis であること" do
        expect(result.reason).to eq(:no_diagnosis)
      end

      it "year が nil であること" do
        expect(result.year).to be_nil
      end

      it "適切なメッセージを返すこと" do
        expect(result.message).to include("歌声診断を完了すると")
      end
    end

    context "当年に完了済み診断がある場合" do
      let(:current_year) { Time.current.year }

      before do
        FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed,
                          created_at: Time.zone.local(current_year, 6, 1))
      end

      it "eligible が true であること" do
        expect(result.eligible?).to be true
      end

      it "year が当年であること" do
        expect(result.year).to eq(current_year)
      end

      it "reason が :eligible であること" do
        expect(result.reason).to eq(:eligible)
      end

      it "completed_diagnoses_count が 1 以上であること" do
        expect(result.completed_diagnoses_count).to be >= 1
      end
    end

    context "既存 movie が pending の場合" do
      let(:current_year) { Time.current.year }

      before do
        FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed,
                          created_at: Time.zone.local(current_year, 6, 1))
        FactoryBot.create(:singing_generated_recap_movie,
                          customer: customer, year: current_year, status: :pending)
      end

      it "eligible が false であること" do
        expect(result.eligible?).to be false
      end

      it "reason が :already_pending であること" do
        expect(result.reason).to eq(:already_pending)
      end
    end

    context "既存 movie が processing の場合" do
      let(:current_year) { Time.current.year }

      before do
        FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed,
                          created_at: Time.zone.local(current_year, 6, 1))
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

    context "既存 movie が completed（reusable）の場合" do
      let(:current_year) { Time.current.year }

      before do
        FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed,
                          created_at: Time.zone.local(current_year, 6, 1))
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

    context "既存 movie が failed の場合" do
      let(:current_year) { Time.current.year }

      before do
        FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed,
                          created_at: Time.zone.local(current_year, 6, 1))
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

    context "既存 movie が expired の場合" do
      let(:current_year) { Time.current.year }

      before do
        FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed,
                          created_at: Time.zone.local(current_year, 6, 1))
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
        FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed,
                          created_at: Time.zone.local(2024, 6, 1))

        result = described_class.call(customer, year: 2024)

        expect(result.year).to eq(2024)
      end
    end
  end
end
