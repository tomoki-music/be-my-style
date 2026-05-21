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
