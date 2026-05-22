require "rails_helper"

RSpec.describe Singing::RecapMovieStorageAuditService do
  subject(:result) { described_class.call }

  let(:customer)  { create(:customer, domain_name: "singing") }
  let(:customer2) { create(:customer, domain_name: "singing") }

  describe ".call" do
    it "必要なキーを全て返すこと" do
      expect(result.keys).to contain_exactly(
        :completed_without_file_count,
        :cleaned_but_attached_count,
        :completed_without_file,
        :cleaned_but_attached,
        :has_anomalies,
        :audited_at,
      )
    end

    it "audited_at が Time オブジェクトであること" do
      expect(result[:audited_at]).to be_a(Time).or be_a(ActiveSupport::TimeWithZone)
    end
  end

  describe "#completed_without_file" do
    context "異常なし: completed かつ video_file が attached されている場合" do
      before { create(:singing_generated_recap_movie, :completed, customer: customer) }

      it "completed_without_file_count が 0 であること" do
        expect(result[:completed_without_file_count]).to eq(0)
      end

      it "has_anomalies が false であること" do
        expect(result[:has_anomalies]).to be false
      end
    end

    context "異常あり: completed だが video_file が存在しない場合" do
      let!(:movie) do
        m = create(:singing_generated_recap_movie, :completed, customer: customer)
        m.video_file.detach
        m
      end

      it "completed_without_file_count が 1 であること" do
        expect(result[:completed_without_file_count]).to eq(1)
      end

      it "completed_without_file に対象レコードが含まれること" do
        ids = result[:completed_without_file].map(&:id)
        expect(ids).to include(movie.id)
      end

      it "has_anomalies が true であること" do
        expect(result[:has_anomalies]).to be true
      end
    end

    context "expired の movie は completed_without_file に含まれないこと" do
      before { create(:singing_generated_recap_movie, :expired, customer: customer) }

      it "completed_without_file_count が 0 であること" do
        expect(result[:completed_without_file_count]).to eq(0)
      end
    end

    context "failed / pending の movie は completed_without_file に含まれないこと" do
      before do
        create(:singing_generated_recap_movie, :failed,   customer: customer)
        create(:singing_generated_recap_movie, customer:  customer2, status: :pending)
      end

      it "completed_without_file_count が 0 であること" do
        expect(result[:completed_without_file_count]).to eq(0)
      end
    end
  end

  describe "#cleaned_but_attached" do
    context "異常なし: cleaned_up_at あり・video_file なし (正常 expire 済み)" do
      before do
        create(:singing_generated_recap_movie, :expired, customer: customer,
               cleaned_up_at: 1.hour.ago)
      end

      it "cleaned_but_attached_count が 0 であること" do
        expect(result[:cleaned_but_attached_count]).to eq(0)
      end
    end

    context "異常あり: expired + cleaned_up_at あり + video_file がまだ attached の場合" do
      let!(:movie) do
        m = create(:singing_generated_recap_movie, :expired, customer: customer,
                   cleaned_up_at: 1.hour.ago)
        m.video_file.attach(
          io:           StringIO.new("MP4"),
          filename:     "recap_test.mp4",
          content_type: "video/mp4",
        )
        m
      end

      it "cleaned_but_attached_count が 1 であること" do
        expect(result[:cleaned_but_attached_count]).to eq(1)
      end

      it "cleaned_but_attached に対象レコードが含まれること" do
        ids = result[:cleaned_but_attached].map(&:id)
        expect(ids).to include(movie.id)
      end

      it "has_anomalies が true であること" do
        expect(result[:has_anomalies]).to be true
      end
    end

    context "expired だが cleaned_up_at が nil の場合 (未処理) は含まれないこと" do
      before do
        m = create(:singing_generated_recap_movie, :expired, customer: customer,
                   cleaned_up_at: nil)
        m.video_file.attach(
          io:           StringIO.new("MP4"),
          filename:     "recap_test.mp4",
          content_type: "video/mp4",
        )
      end

      it "cleaned_but_attached_count が 0 であること" do
        expect(result[:cleaned_but_attached_count]).to eq(0)
      end
    end
  end

  describe "has_anomalies" do
    context "どちらの異常もない場合" do
      before { create(:singing_generated_recap_movie, :completed, customer: customer) }

      it "has_anomalies が false であること" do
        expect(result[:has_anomalies]).to be false
      end
    end

    context "completed_without_file だけある場合" do
      before do
        m = create(:singing_generated_recap_movie, :completed, customer: customer)
        m.video_file.detach
      end

      it "has_anomalies が true であること" do
        expect(result[:has_anomalies]).to be true
      end
    end

    context "cleaned_but_attached だけある場合" do
      before do
        m = create(:singing_generated_recap_movie, :expired, customer: customer,
                   cleaned_up_at: 1.hour.ago)
        m.video_file.attach(
          io:           StringIO.new("MP4"),
          filename:     "recap_test.mp4",
          content_type: "video/mp4",
        )
      end

      it "has_anomalies が true であること" do
        expect(result[:has_anomalies]).to be true
      end
    end
  end

  describe "AUDIT_RECORD_LIMIT" do
    it "定数が定義されていること" do
      expect(described_class::AUDIT_RECORD_LIMIT).to be_a(Integer)
      expect(described_class::AUDIT_RECORD_LIMIT).to be > 0
    end
  end
end
