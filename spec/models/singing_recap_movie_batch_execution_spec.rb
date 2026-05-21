require 'rails_helper'

RSpec.describe SingingRecapMovieBatchExecution, type: :model do
  let(:admin) { FactoryBot.create(:admin) }

  describe "バリデーション" do
    subject(:execution) do
      FactoryBot.build(:singing_recap_movie_batch_execution, admin: admin)
    end

    it "有効なレコードが作成できること" do
      expect(execution).to be_valid
    end

    it "year が必須であること" do
      execution.year = nil
      expect(execution).not_to be_valid
      expect(execution.errors[:year]).to be_present
    end

    it "year が整数でなければ無効であること" do
      execution.year = 2025.5
      expect(execution).not_to be_valid
    end

    it "year が 2000 以下は無効であること" do
      execution.year = 2000
      expect(execution).not_to be_valid
    end

    it "year が 2100 を超えると無効であること" do
      execution.year = 2101
      expect(execution).not_to be_valid
    end

    it "status が必須であること" do
      execution.status = nil
      expect(execution).not_to be_valid
    end

    it "admin が nil でも有効であること（optional）" do
      execution.admin = nil
      expect(execution).to be_valid
    end
  end

  describe "#skipped_breakdown_hash" do
    it "skipped_breakdown が nil の場合は空ハッシュを返すこと" do
      execution = FactoryBot.build(:singing_recap_movie_batch_execution, skipped_breakdown: nil)
      expect(execution.skipped_breakdown_hash).to eq({})
    end

    it "skipped_breakdown が存在する場合はその値を返すこと" do
      breakdown = { "pending" => 2, "processing" => 1, "completed" => 0 }
      execution = FactoryBot.build(:singing_recap_movie_batch_execution, skipped_breakdown: breakdown)
      expect(execution.skipped_breakdown_hash).to eq(breakdown)
    end
  end

  describe "enum status" do
    it "enqueued ステータスが使えること" do
      execution = FactoryBot.create(:singing_recap_movie_batch_execution, admin: admin)
      expect(execution.enqueued?).to be true
    end

    it "running ステータスが使えること" do
      execution = FactoryBot.create(:singing_recap_movie_batch_execution, admin: admin, status: :running)
      expect(execution.running?).to be true
    end

    it "completed ステータスが使えること" do
      execution = FactoryBot.create(:singing_recap_movie_batch_execution, admin: admin, status: :completed)
      expect(execution.completed?).to be true
    end

    it "failed ステータスが使えること" do
      execution = FactoryBot.create(:singing_recap_movie_batch_execution, admin: admin, status: :failed)
      expect(execution.failed?).to be true
    end
  end

  describe ".active_for_year" do
    let(:year) { 2025 }

    it "enqueued のレコードを返すこと" do
      exec = FactoryBot.create(:singing_recap_movie_batch_execution, year: year, status: :enqueued)
      expect(SingingRecapMovieBatchExecution.active_for_year(year)).to include(exec)
    end

    it "running のレコードを返すこと" do
      exec = FactoryBot.create(:singing_recap_movie_batch_execution, year: year, status: :running)
      expect(SingingRecapMovieBatchExecution.active_for_year(year)).to include(exec)
    end

    it "completed のレコードは返さないこと" do
      FactoryBot.create(:singing_recap_movie_batch_execution, year: year, status: :completed)
      expect(SingingRecapMovieBatchExecution.active_for_year(year)).to be_empty
    end

    it "failed のレコードは返さないこと" do
      FactoryBot.create(:singing_recap_movie_batch_execution, year: year, status: :failed)
      expect(SingingRecapMovieBatchExecution.active_for_year(year)).to be_empty
    end

    it "別の year のレコードは返さないこと" do
      FactoryBot.create(:singing_recap_movie_batch_execution, year: year + 1, status: :enqueued)
      expect(SingingRecapMovieBatchExecution.active_for_year(year)).to be_empty
    end
  end

  describe "#active?" do
    it "enqueued の場合は true を返すこと" do
      execution = FactoryBot.build(:singing_recap_movie_batch_execution, status: :enqueued)
      expect(execution.active?).to be true
    end

    it "running の場合は true を返すこと" do
      execution = FactoryBot.build(:singing_recap_movie_batch_execution, status: :running)
      expect(execution.active?).to be true
    end

    it "completed の場合は false を返すこと" do
      execution = FactoryBot.build(:singing_recap_movie_batch_execution, status: :completed)
      expect(execution.active?).to be false
    end

    it "failed の場合は false を返すこと" do
      execution = FactoryBot.build(:singing_recap_movie_batch_execution, status: :failed)
      expect(execution.active?).to be false
    end
  end

  describe "belongs_to :admin" do
    it "admin に紐付けられること" do
      execution = FactoryBot.create(:singing_recap_movie_batch_execution, admin: admin)
      expect(execution.admin).to eq(admin)
    end

    it "admin なしで作成できること" do
      execution = FactoryBot.create(:singing_recap_movie_batch_execution, admin: nil)
      expect(execution.admin).to be_nil
    end
  end

  describe "カウント項目" do
    it "デフォルト値が 0 であること" do
      execution = SingingRecapMovieBatchExecution.new(year: 2025, status: :enqueued)
      expect(execution.target_customers_count).to eq(0)
      expect(execution.new_movies_count).to eq(0)
      expect(execution.regenerate_movies_count).to eq(0)
      expect(execution.skipped_movies_count).to eq(0)
    end
  end
end
