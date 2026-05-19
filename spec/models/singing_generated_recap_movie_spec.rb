require "rails_helper"

RSpec.describe SingingGeneratedRecapMovie, type: :model do
  let(:customer) { create(:customer, domain_name: "singing") }

  describe "バリデーション" do
    it "正常なレコードは valid になる" do
      movie = build(:singing_generated_recap_movie, customer: customer)
      expect(movie).to be_valid
    end

    it "year が未指定だと invalid になる" do
      movie = build(:singing_generated_recap_movie, customer: customer, year: nil)
      expect(movie).not_to be_valid
      expect(movie.errors[:year]).to be_present
    end

    it "year が 2000 以下だと invalid になる" do
      movie = build(:singing_generated_recap_movie, customer: customer, year: 2000)
      expect(movie).not_to be_valid
    end

    it "status が未指定だと invalid になる" do
      movie = build(:singing_generated_recap_movie, customer: customer, status: nil)
      expect(movie).not_to be_valid
      expect(movie.errors[:status]).to be_present
    end

    it "同一 customer_id + year の重複は invalid になる" do
      create(:singing_generated_recap_movie, customer: customer, year: 2025)
      dup = build(:singing_generated_recap_movie, customer: customer, year: 2025)
      expect(dup).not_to be_valid
      expect(dup.errors[:customer_id]).to be_present
    end

    it "別 customer の同 year は valid になる" do
      other = create(:customer, domain_name: "singing")
      create(:singing_generated_recap_movie, customer: customer, year: 2025)
      movie = build(:singing_generated_recap_movie, customer: other, year: 2025)
      expect(movie).to be_valid
    end
  end

  describe "status enum" do
    it "pending / processing / completed / failed / expired が設定できる" do
      %i[pending processing completed failed expired].each do |s|
        movie = build(:singing_generated_recap_movie, customer: customer, status: s)
        expect(movie.status).to eq(s.to_s)
      end
    end
  end

  describe "#reusable?" do
    it "completed かつ expires_at が未来なら true" do
      movie = build(:singing_generated_recap_movie, :completed, customer: customer, expires_at: 1.day.from_now)
      expect(movie).to be_reusable
    end

    it "completed かつ expires_at が nil なら true" do
      movie = build(:singing_generated_recap_movie, :completed, customer: customer, expires_at: nil)
      expect(movie).to be_reusable
    end

    it "completed かつ expires_at が過去なら false" do
      movie = build(:singing_generated_recap_movie, :completed, customer: customer, expires_at: 1.second.ago)
      expect(movie).not_to be_reusable
    end

    it "failed なら false" do
      movie = build(:singing_generated_recap_movie, :failed, customer: customer)
      expect(movie).not_to be_reusable
    end
  end

  describe "#mark_processing!" do
    it "status を processing に更新する" do
      movie = create(:singing_generated_recap_movie, customer: customer)
      movie.mark_processing!
      expect(movie.reload.status).to eq("processing")
    end
  end

  describe "#mark_completed!" do
    it "status を completed に、generated_at を記録する" do
      movie = create(:singing_generated_recap_movie, customer: customer, status: :processing)
      freeze_time = Time.current
      movie.mark_completed!(generated_time: freeze_time)
      movie.reload
      expect(movie.status).to eq("completed")
      expect(movie.generated_at).to be_within(1.second).of(freeze_time)
    end
  end

  describe "#mark_failed!" do
    it "status を failed に、error_message を記録する" do
      movie = create(:singing_generated_recap_movie, customer: customer, status: :processing)
      movie.mark_failed!("render timeout")
      movie.reload
      expect(movie.status).to eq("failed")
      expect(movie.error_message).to eq("render timeout")
    end
  end

  describe "Customer との関連" do
    it "Customer に has_many :singing_generated_recap_movies が設定されている" do
      movie = create(:singing_generated_recap_movie, customer: customer)
      expect(customer.singing_generated_recap_movies).to include(movie)
    end

    it "customer を destroy すると連鎖削除される" do
      create(:singing_generated_recap_movie, customer: customer)
      expect { customer.destroy }.to change(SingingGeneratedRecapMovie, :count).by(-1)
    end
  end

  describe ".reusable scope" do
    it "completed かつ expires_at が未来のレコードを返す" do
      reusable = create(:singing_generated_recap_movie, :completed, customer: customer, expires_at: 1.day.from_now)
      create(:singing_generated_recap_movie, :failed, customer: create(:customer, domain_name: "singing"), year: 2025)

      expect(SingingGeneratedRecapMovie.reusable).to include(reusable)
    end

    it "expires_at が過去のレコードは含まない" do
      create(:singing_generated_recap_movie, :completed, customer: customer, expires_at: 1.second.ago)
      expect(SingingGeneratedRecapMovie.reusable).to be_empty
    end
  end

  describe ".expired_targets scope" do
    it "expires_at が過去かつ非 expired ステータスのレコードを返す" do
      target = create(:singing_generated_recap_movie, :completed, customer: customer, expires_at: 1.second.ago)
      expect(SingingGeneratedRecapMovie.expired_targets).to include(target)
    end

    it "expires_at が未来のレコードは含まない" do
      create(:singing_generated_recap_movie, :completed, customer: customer, expires_at: 1.day.from_now)
      expect(SingingGeneratedRecapMovie.expired_targets).to be_empty
    end

    it "expires_at が nil のレコードは含まない" do
      create(:singing_generated_recap_movie, :completed, customer: customer, expires_at: nil)
      expect(SingingGeneratedRecapMovie.expired_targets).to be_empty
    end

    it "already expired なレコードは含まない" do
      create(:singing_generated_recap_movie, :expired, customer: customer)
      expect(SingingGeneratedRecapMovie.expired_targets).to be_empty
    end

    it "pending / processing / failed も期限切れなら含む" do
      other1 = create(:customer, domain_name: "singing")
      other2 = create(:customer, domain_name: "singing")
      pending_movie    = create(:singing_generated_recap_movie, customer: customer, status: :pending, expires_at: 1.second.ago)
      processing_movie = create(:singing_generated_recap_movie, customer: other1,   status: :processing, expires_at: 1.second.ago)
      failed_movie     = create(:singing_generated_recap_movie, customer: other2,   status: :failed, expires_at: 1.second.ago)

      results = SingingGeneratedRecapMovie.expired_targets
      expect(results).to include(pending_movie, processing_movie, failed_movie)
    end
  end

  describe "#expire!" do
    context "completed でファイルが添付されている場合" do
      it "video_file を purge_later し、status を expired に、error_message を nil にする" do
        movie = create(:singing_generated_recap_movie, :completed, customer: customer, expires_at: 1.second.ago, error_message: nil)
        expect(movie.video_file).to be_attached

        expect(movie.video_file).to receive(:purge_later)
        movie.expire!
        movie.reload

        expect(movie.status).to eq("expired")
        expect(movie.error_message).to be_nil
      end
    end

    context "completed でファイルが添付されていない場合" do
      it "purge_later を呼ばずに status を expired にする" do
        movie = create(:singing_generated_recap_movie, customer: customer, status: :completed, generated_at: Time.current, expires_at: 1.second.ago)
        expect(movie.video_file).not_to be_attached

        expect(movie.video_file).not_to receive(:purge_later)
        movie.expire!

        expect(movie.reload.status).to eq("expired")
      end
    end

    context "pending の場合" do
      it "status を expired にする" do
        movie = create(:singing_generated_recap_movie, customer: customer, status: :pending, expires_at: 1.second.ago)
        movie.expire!
        expect(movie.reload.status).to eq("expired")
      end
    end

    context "processing の場合" do
      it "status を expired にする" do
        movie = create(:singing_generated_recap_movie, customer: customer, status: :processing, expires_at: 1.second.ago)
        movie.expire!
        expect(movie.reload.status).to eq("expired")
      end
    end

    context "failed の場合" do
      it "status を expired にし、error_message は保持する" do
        movie = create(:singing_generated_recap_movie, :failed, customer: customer, expires_at: 1.second.ago)
        movie.expire!
        expect(movie.reload.status).to eq("expired")
        expect(movie.reload.error_message).to eq("Remotion render failed")
      end
    end
  end
end
