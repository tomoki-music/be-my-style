require "rails_helper"

RSpec.describe Singing::RecapMovieBatchPreviewService, type: :service do
  let(:year) { 2025 }

  let!(:customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let!(:diagnosis) do
    FactoryBot.create(:singing_diagnosis, :completed,
                      customer: customer,
                      created_at: Time.zone.local(2025, 6, 1))
  end

  subject(:preview) { described_class.call(year) }

  describe "戻り値の構造" do
    it "year キーが含まれること" do
      expect(preview[:year]).to eq(year)
    end

    it "target_customers_count が含まれること" do
      expect(preview).to have_key(:target_customers_count)
    end

    it "new_movies_count / regenerate_movies_count / skipped_movies_count が含まれること" do
      expect(preview).to have_key(:new_movies_count)
      expect(preview).to have_key(:regenerate_movies_count)
      expect(preview).to have_key(:skipped_movies_count)
    end

    it "skipped_breakdown が pending / processing / completed を持つこと" do
      expect(preview[:skipped_breakdown]).to include(:pending, :processing, :completed)
    end
  end

  describe "movie なし → new" do
    it "target_customers_count が 1 であること" do
      expect(preview[:target_customers_count]).to eq(1)
    end

    it "new_movies_count が 1 であること" do
      expect(preview[:new_movies_count]).to eq(1)
    end

    it "regenerate / skipped が 0 であること" do
      expect(preview[:regenerate_movies_count]).to eq(0)
      expect(preview[:skipped_movies_count]).to eq(0)
    end
  end

  describe "failed movie → regenerate" do
    let!(:movie) do
      FactoryBot.create(:singing_generated_recap_movie, :failed,
                        customer: customer, year: year)
    end

    it "regenerate_movies_count が 1 であること" do
      expect(preview[:regenerate_movies_count]).to eq(1)
    end

    it "new / skipped が 0 であること" do
      expect(preview[:new_movies_count]).to eq(0)
      expect(preview[:skipped_movies_count]).to eq(0)
    end
  end

  describe "expired movie → regenerate" do
    let!(:movie) do
      FactoryBot.create(:singing_generated_recap_movie, :expired,
                        customer: customer, year: year)
    end

    it "regenerate_movies_count が 1 であること" do
      expect(preview[:regenerate_movies_count]).to eq(1)
    end
  end

  describe "pending movie → skipped" do
    let!(:movie) do
      FactoryBot.create(:singing_generated_recap_movie,
                        customer: customer, year: year, status: :pending)
    end

    it "skipped_movies_count が 1 であること" do
      expect(preview[:skipped_movies_count]).to eq(1)
    end

    it "skipped_breakdown[:pending] が 1 であること" do
      expect(preview[:skipped_breakdown][:pending]).to eq(1)
    end

    it "new / regenerate が 0 であること" do
      expect(preview[:new_movies_count]).to eq(0)
      expect(preview[:regenerate_movies_count]).to eq(0)
    end
  end

  describe "processing movie → skipped" do
    let!(:movie) do
      FactoryBot.create(:singing_generated_recap_movie, :processing,
                        customer: customer, year: year)
    end

    it "skipped_movies_count が 1 であること" do
      expect(preview[:skipped_movies_count]).to eq(1)
    end

    it "skipped_breakdown[:processing] が 1 であること" do
      expect(preview[:skipped_breakdown][:processing]).to eq(1)
    end
  end

  describe "completed movie → skipped" do
    let!(:movie) do
      FactoryBot.create(:singing_generated_recap_movie, :completed,
                        customer: customer, year: year)
    end

    it "skipped_movies_count が 1 であること" do
      expect(preview[:skipped_movies_count]).to eq(1)
    end

    it "skipped_breakdown[:completed] が 1 であること" do
      expect(preview[:skipped_breakdown][:completed]).to eq(1)
    end
  end

  describe "skipped_breakdown の内訳が正しいこと" do
    let!(:customer2) { FactoryBot.create(:customer, domain_name: "singing") }
    let!(:customer3) { FactoryBot.create(:customer, domain_name: "singing") }

    let!(:diagnosis2) do
      FactoryBot.create(:singing_diagnosis, :completed,
                        customer: customer2, created_at: Time.zone.local(2025, 3, 1))
    end
    let!(:diagnosis3) do
      FactoryBot.create(:singing_diagnosis, :completed,
                        customer: customer3, created_at: Time.zone.local(2025, 9, 1))
    end

    let!(:pending_movie) do
      FactoryBot.create(:singing_generated_recap_movie,
                        customer: customer, year: year, status: :pending)
    end
    let!(:completed_movie) do
      FactoryBot.create(:singing_generated_recap_movie, :completed,
                        customer: customer2, year: year)
    end

    it "skipped_breakdown が pending:1 completed:1 であること" do
      result = described_class.call(year)
      expect(result[:skipped_breakdown][:pending]).to eq(1)
      expect(result[:skipped_breakdown][:completed]).to eq(1)
      expect(result[:skipped_breakdown][:processing]).to eq(0)
    end

    it "customer3 は movie なしなので new に計上されること" do
      result = described_class.call(year)
      expect(result[:new_movies_count]).to eq(1)
      expect(result[:skipped_movies_count]).to eq(2)
    end
  end

  describe "対象外ケースの除外" do
    context "is_deleted: true のユーザー" do
      let!(:deleted_customer) { FactoryBot.create(:customer, domain_name: "singing", is_deleted: true) }
      let!(:deleted_diagnosis) do
        FactoryBot.create(:singing_diagnosis, :completed,
                          customer: deleted_customer, created_at: Time.zone.local(2025, 5, 1))
      end

      it "削除済みユーザーは対象に含まれないこと" do
        expect(preview[:target_customers_count]).to eq(1)
      end
    end

    context "指定年外の diagnosis しかないユーザー" do
      let!(:customer_other_year) { FactoryBot.create(:customer, domain_name: "singing") }
      let!(:other_year_diagnosis) do
        FactoryBot.create(:singing_diagnosis, :completed,
                          customer: customer_other_year, created_at: Time.zone.local(2024, 6, 1))
      end

      it "指定年外のユーザーは対象に含まれないこと" do
        expect(preview[:target_customers_count]).to eq(1)
      end
    end

    context "singing domain 以外のユーザー" do
      let!(:music_customer) { FactoryBot.create(:customer, domain_name: "music") }
      let!(:music_diagnosis) do
        FactoryBot.create(:singing_diagnosis, :completed,
                          customer: music_customer, created_at: Time.zone.local(2025, 6, 1))
      end

      it "singing domain 外ユーザーは対象に含まれないこと" do
        expect(preview[:target_customers_count]).to eq(1)
      end
    end

    context "completed でない diagnosis しかないユーザー" do
      let!(:customer_queued) { FactoryBot.create(:customer, domain_name: "singing") }
      let!(:queued_diagnosis) do
        FactoryBot.create(:singing_diagnosis,
                          customer: customer_queued, created_at: Time.zone.local(2025, 6, 1))
      end

      it "未完了 diagnosis のユーザーは対象に含まれないこと" do
        expect(preview[:target_customers_count]).to eq(1)
      end
    end

    context "対象ユーザーが 0 人の場合" do
      before { SingingDiagnosis.destroy_all }

      it "全件 0 で落ちないこと" do
        result = described_class.call(year)
        expect(result[:target_customers_count]).to eq(0)
        expect(result[:new_movies_count]).to eq(0)
        expect(result[:regenerate_movies_count]).to eq(0)
        expect(result[:skipped_movies_count]).to eq(0)
      end
    end
  end
end
