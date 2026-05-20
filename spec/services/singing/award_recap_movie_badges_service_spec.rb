require "rails_helper"

RSpec.describe Singing::AwardRecapMovieBadgesService, type: :service do
  let(:customer) { create(:customer, domain_name: "singing") }
  let(:recap_movie) { create(:singing_generated_recap_movie, :completed, customer: customer, year: 2024) }

  describe ".call" do
    context "kind=x" do
      it "recap_movie_first_share バッジを付与すること" do
        described_class.call(recap_movie, "x")

        expect(SingingAchievementBadge.where(customer: customer, badge_key: "recap_movie_first_share")).to exist
      end

      it "metadata に schema_version: 1 が含まれること" do
        described_class.call(recap_movie, "x")

        badge = SingingAchievementBadge.find_by(customer: customer, badge_key: "recap_movie_first_share")
        expect(badge.metadata["schema_version"]).to eq(1)
      end

      it "metadata に recap_movie_year が含まれること" do
        described_class.call(recap_movie, "x")

        badge = SingingAchievementBadge.find_by(customer: customer, badge_key: "recap_movie_first_share")
        expect(badge.metadata["recap_movie_year"]).to eq(2024)
      end

      it "2回呼んでもバッジは1件のみであること（重複防止）" do
        described_class.call(recap_movie, "x")
        described_class.call(recap_movie, "x")

        expect(SingingAchievementBadge.where(customer: customer, badge_key: "recap_movie_first_share").count).to eq(1)
      end
    end

    context "kind=download" do
      it "recap_movie_first_download バッジを付与すること" do
        described_class.call(recap_movie, "download")

        expect(SingingAchievementBadge.where(customer: customer, badge_key: "recap_movie_first_download")).to exist
      end

      it "2回呼んでもバッジは1件のみであること（重複防止）" do
        described_class.call(recap_movie, "download")
        described_class.call(recap_movie, "download")

        expect(SingingAchievementBadge.where(customer: customer, badge_key: "recap_movie_first_download").count).to eq(1)
      end
    end

    context "kind=instagram" do
      it "recap_movie_instagram_share バッジを付与すること" do
        described_class.call(recap_movie, "instagram")

        expect(SingingAchievementBadge.where(customer: customer, badge_key: "recap_movie_instagram_share")).to exist
      end

      it "2回呼んでもバッジは1件のみであること（重複防止）" do
        described_class.call(recap_movie, "instagram")
        described_class.call(recap_movie, "instagram")

        expect(SingingAchievementBadge.where(customer: customer, badge_key: "recap_movie_instagram_share").count).to eq(1)
      end
    end

    context "unknown kind" do
      it "バッジを付与しないこと" do
        expect {
          described_class.call(recap_movie, "unknown")
        }.not_to change(SingingAchievementBadge, :count)
      end
    end
  end
end
