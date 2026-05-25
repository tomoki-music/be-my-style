require "rails_helper"

RSpec.describe Singing::RecapMovieStorageMetricsService do
  subject(:result) { described_class.call }

  let(:customer) { create(:customer, domain_name: "singing") }

  describe ".call" do
    it "必要なキーを全て返すこと" do
      expect(result.keys).to contain_exactly(
        :attached_movie_count,
        :total_bytes,
        :avg_bytes,
        :completed_bytes,
        :expired_attached_bytes,
        :recent_bytes,
        :cost_estimation,
        :year_breakdown,
        :plan_breakdown,
        :collected_at,
      )
    end

    it "collected_at が Time オブジェクトであること" do
      expect(result[:collected_at]).to be_a(Time).or be_a(ActiveSupport::TimeWithZone)
    end
  end

  describe "#attached_movie_count" do
    context "動画ファイルが存在しない場合" do
      before { create(:singing_generated_recap_movie, customer: customer) }

      it "0 を返すこと" do
        expect(result[:attached_movie_count]).to eq(0)
      end
    end

    context "completed 動画が 2 件ある場合" do
      let(:customer2) { create(:customer, domain_name: "singing") }

      before do
        create(:singing_generated_recap_movie, :completed, customer: customer, year: 2024)
        create(:singing_generated_recap_movie, :completed, customer: customer2, year: 2024)
      end

      it "2 を返すこと" do
        expect(result[:attached_movie_count]).to eq(2)
      end
    end

    context "expired だがファイルが残っている場合もカウントすること" do
      before do
        m = create(:singing_generated_recap_movie, :expired, customer: customer)
        m.video_file.attach(
          io:           StringIO.new("MP4"),
          filename:     "recap.mp4",
          content_type: "video/mp4",
        )
      end

      it "1 を返すこと" do
        expect(result[:attached_movie_count]).to eq(1)
      end
    end
  end

  describe "#total_bytes / #avg_bytes" do
    context "動画が 0 件の場合" do
      it "total_bytes が 0 であること" do
        expect(result[:total_bytes]).to eq(0)
      end

      it "avg_bytes が 0 であること" do
        expect(result[:avg_bytes]).to eq(0)
      end
    end

    context "completed 動画が 1 件の場合" do
      before { create(:singing_generated_recap_movie, :completed, customer: customer) }

      it "total_bytes が正の整数であること" do
        expect(result[:total_bytes]).to be_a(Integer).and be > 0
      end

      it "avg_bytes が total_bytes と同じであること" do
        expect(result[:avg_bytes]).to eq(result[:total_bytes])
      end
    end
  end

  describe "#completed_bytes" do
    context "completed 動画のみ存在する場合" do
      before { create(:singing_generated_recap_movie, :completed, customer: customer) }

      it "completed のファイルサイズを返すこと" do
        expect(result[:completed_bytes]).to eq(result[:total_bytes])
      end
    end

    context "failed / pending 動画は含まれないこと" do
      before do
        create(:singing_generated_recap_movie, :failed,   customer: customer)
        create(:singing_generated_recap_movie,            customer: customer, year: 2023)
      end

      it "completed_bytes が 0 であること" do
        expect(result[:completed_bytes]).to eq(0)
      end
    end
  end

  describe "#expired_attached_bytes" do
    context "expired でファイルが残っている場合" do
      before do
        m = create(:singing_generated_recap_movie, :expired, customer: customer)
        m.video_file.attach(
          io:           StringIO.new("MP4DATA"),
          filename:     "recap.mp4",
          content_type: "video/mp4",
        )
      end

      it "正の値を返すこと" do
        expect(result[:expired_attached_bytes]).to be > 0
      end
    end

    context "expired だがファイルがない場合" do
      before { create(:singing_generated_recap_movie, :expired, customer: customer) }

      it "0 を返すこと" do
        expect(result[:expired_attached_bytes]).to eq(0)
      end
    end
  end

  describe "#recent_bytes" do
    context "直近30日以内に生成された completed 動画がある場合" do
      before do
        create(:singing_generated_recap_movie, :completed, customer: customer,
               generated_at: 7.days.ago)
      end

      it "正の値を返すこと" do
        expect(result[:recent_bytes]).to be > 0
      end
    end

    context "30日より古い動画は含まれないこと" do
      before do
        m = create(:singing_generated_recap_movie, :completed, customer: customer,
                   generated_at: 40.days.ago)
        # generated_at をオーバーライド (factory は Time.current を使うため)
        m.update_column(:generated_at, 40.days.ago)
      end

      it "0 を返すこと" do
        expect(result[:recent_bytes]).to eq(0)
      end
    end
  end

  describe "#build_cost_estimation" do
    subject(:cost) { result[:cost_estimation] }

    it "必要なキーを全て返すこと" do
      expect(cost.keys).to contain_exactly(
        :total_gb, :monthly_cost_usd, :price_per_gb_usd, :note
      )
    end

    it "price_per_gb_usd が定数と一致すること" do
      expect(cost[:price_per_gb_usd]).to eq(described_class::S3_PRICE_PER_GB_USD)
    end

    it "total_gb が total_bytes から正しく換算されること" do
      create(:singing_generated_recap_movie, :completed, customer: customer)
      expected_gb = result[:total_bytes].to_f / described_class::BYTES_PER_GB
      expect(cost[:total_gb]).to be_within(0.001).of(expected_gb.round(3))
    end

    it "note が概算の注意書きを含むこと" do
      expect(cost[:note]).to include("概算")
      expect(cost[:note]).to include("転送料")
    end
  end

  describe "#build_year_breakdown" do
    subject(:breakdown) { result[:year_breakdown] }

    context "複数年の completed 動画がある場合" do
      let(:customer2) { create(:customer, domain_name: "singing") }

      before do
        create(:singing_generated_recap_movie, :completed, customer: customer,  year: 2024)
        create(:singing_generated_recap_movie, :completed, customer: customer2, year: 2023)
      end

      it "年ごとのエントリを返すこと" do
        years = breakdown.map { |r| r[:year] }
        expect(years).to include(2024, 2023)
      end

      it "各エントリに year / count / bytes が含まれること" do
        expect(breakdown.first.keys).to contain_exactly(:year, :count, :bytes)
      end

      it "新しい年順に並んでいること" do
        years = breakdown.map { |r| r[:year] }
        expect(years).to eq(years.sort.reverse)
      end

      it "各 year の count が正しいこと" do
        row_2024 = breakdown.find { |r| r[:year] == 2024 }
        expect(row_2024[:count]).to eq(1)
      end
    end

    context "動画がない場合" do
      it "空配列を返すこと" do
        expect(breakdown).to be_empty
      end
    end
  end

  describe "#build_plan_breakdown" do
    subject(:breakdown) { result[:plan_breakdown] }

    context "異なるプランのユーザーが動画を持つ場合" do
      let(:premium_customer) { create(:customer, domain_name: "singing") }
      let(:free_customer)    { create(:customer, domain_name: "singing") }

      before do
        # premium customer: subscription あり
        create(:singing_generated_recap_movie, :completed, customer: premium_customer, year: 2024)
        Subscription.create!(customer: premium_customer, plan: "premium", status: "active")

        # free customer: subscription なし → plan は 'free' 扱い
        create(:singing_generated_recap_movie, :completed, customer: free_customer, year: 2024)
      end

      it "premium と free が含まれること" do
        plans = breakdown.map { |r| r[:plan] }
        expect(plans).to include("premium", "free")
      end

      it "premium が free より先に並ぶこと" do
        plans = breakdown.map { |r| r[:plan] }
        expect(plans.index("premium")).to be < plans.index("free")
      end

      it "各エントリに plan / count / bytes が含まれること" do
        expect(breakdown.first.keys).to contain_exactly(:plan, :count, :bytes)
      end
    end

    context "動画がない場合" do
      it "空配列を返すこと" do
        expect(breakdown).to be_empty
      end
    end
  end

  describe "定数" do
    it "S3_PRICE_PER_GB_USD が正の数であること" do
      expect(described_class::S3_PRICE_PER_GB_USD).to be > 0
    end

    it "BYTES_PER_GB が 1073741824 であること" do
      expect(described_class::BYTES_PER_GB).to eq(1_073_741_824.0)
    end

    it "RECENT_DAYS が正の整数であること" do
      expect(described_class::RECENT_DAYS).to be_a(Integer).and be > 0
    end
  end
end
