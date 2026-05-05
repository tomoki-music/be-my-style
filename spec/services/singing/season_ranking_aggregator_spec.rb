require 'rails_helper'

RSpec.describe Singing::SeasonRankingAggregator do
  let(:season) do
    FactoryBot.create(
      :singing_ranking_season,
      starts_on: Date.new(2026, 5, 1),
      ends_on: Date.new(2026, 5, 31),
      status: "active"
    )
  end

  let(:customer_a) { FactoryBot.create(:customer, domain_name: "singing", name: "Aさん") }
  let(:customer_b) { FactoryBot.create(:customer, domain_name: "singing", name: "Bさん") }
  let(:customer_c) { FactoryBot.create(:customer, domain_name: "singing", name: "Cさん") }

  describe "#call" do
    it "overall/pitch/rhythm/expression の entries を作成すること" do
      diagnosis = FactoryBot.create(
        :singing_diagnosis, :completed, :ranking_participant,
        customer: customer_a,
        diagnosed_at: Time.zone.local(2026, 5, 10, 12, 0, 0),
        overall_score: 83,
        pitch_score: 81,
        rhythm_score: 79,
        expression_score: 77
      )

      described_class.new(season).call

      entries = season.singing_season_ranking_entries.order(:category)
      expect(entries.map(&:category)).to contain_exactly("overall", "pitch", "rhythm", "expression")
      expect(entries.map(&:singing_diagnosis_id).uniq).to eq [diagnosis.id]
    end

    it "1ユーザー複数診断の場合はカテゴリごとに最高スコアのみ採用すること" do
      FactoryBot.create(
        :singing_diagnosis, :completed, :ranking_participant,
        customer: customer_a,
        diagnosed_at: Time.zone.local(2026, 5, 5, 12, 0, 0),
        overall_score: 70,
        pitch_score: 95,
        rhythm_score: 70,
        expression_score: 70
      )
      best_overall = FactoryBot.create(
        :singing_diagnosis, :completed, :ranking_participant,
        customer: customer_a,
        diagnosed_at: Time.zone.local(2026, 5, 10, 12, 0, 0),
        overall_score: 83,
        pitch_score: 80,
        rhythm_score: 82,
        expression_score: 81
      )

      described_class.new(season).call

      overall_entry = season.singing_season_ranking_entries.find_by!(category: "overall")
      pitch_entry = season.singing_season_ranking_entries.find_by!(category: "pitch")

      expect(overall_entry.score).to eq 83
      expect(overall_entry.singing_diagnosis_id).to eq best_overall.id
      expect(pitch_entry.score).to eq 95
      expect(pitch_entry.singing_diagnosis_id).not_to eq best_overall.id
    end

    it "ranking_opt_in=false の診断は除外すること" do
      FactoryBot.create(
        :singing_diagnosis, :completed,
        customer: customer_a,
        ranking_opt_in: false,
        diagnosed_at: Time.zone.local(2026, 5, 10, 12, 0, 0),
        overall_score: 99
      )

      described_class.new(season).call

      expect(season.singing_season_ranking_entries).to be_empty
    end

    it "期間外診断は除外すること" do
      FactoryBot.create(
        :singing_diagnosis, :completed, :ranking_participant,
        customer: customer_a,
        diagnosed_at: Time.zone.local(2026, 6, 1, 0, 0, 0),
        overall_score: 99
      )

      described_class.new(season).call

      expect(season.singing_season_ranking_entries).to be_empty
    end

    it "未完了診断は除外すること" do
      FactoryBot.create(
        :singing_diagnosis, :ranking_participant,
        customer: customer_a,
        status: :processing,
        diagnosed_at: Time.zone.local(2026, 5, 10, 12, 0, 0),
        overall_score: 99
      )

      described_class.new(season).call

      expect(season.singing_season_ranking_entries).to be_empty
    end

    it "score が nil のカテゴリは作成しないこと" do
      FactoryBot.create(
        :singing_diagnosis, :completed, :ranking_participant,
        customer: customer_a,
        diagnosed_at: Time.zone.local(2026, 5, 10, 12, 0, 0),
        overall_score: 90,
        pitch_score: nil,
        rhythm_score: nil,
        expression_score: nil
      )

      described_class.new(season).call

      expect(season.singing_season_ranking_entries.pluck(:category)).to eq ["overall"]
    end

    it "score 降順、同点は created_at 昇順で rank を付けること" do
      FactoryBot.create(
        :singing_diagnosis, :completed, :ranking_participant,
        customer: customer_a,
        diagnosed_at: Time.zone.local(2026, 5, 10, 12, 0, 0),
        created_at: Time.zone.local(2026, 5, 10, 10, 0, 0),
        overall_score: 90
      )
      FactoryBot.create(
        :singing_diagnosis, :completed, :ranking_participant,
        customer: customer_b,
        diagnosed_at: Time.zone.local(2026, 5, 10, 12, 0, 0),
        created_at: Time.zone.local(2026, 5, 10, 9, 0, 0),
        overall_score: 90
      )
      FactoryBot.create(
        :singing_diagnosis, :completed, :ranking_participant,
        customer: customer_c,
        diagnosed_at: Time.zone.local(2026, 5, 10, 12, 0, 0),
        overall_score: 80
      )

      described_class.new(season).call

      overall_entries = season.singing_season_ranking_entries.where(category: "overall").order(:rank)
      expect(overall_entries.map(&:customer_id)).to eq [customer_b.id, customer_a.id, customer_c.id]
      expect(overall_entries.map(&:rank)).to eq [1, 2, 3]
    end

    it "title と badge_key を rank/category に応じて付与すること" do
      FactoryBot.create(
        :singing_diagnosis, :completed, :ranking_participant,
        customer: customer_a,
        diagnosed_at: Time.zone.local(2026, 5, 10, 12, 0, 0),
        overall_score: 90,
        pitch_score: 90,
        rhythm_score: 90,
        expression_score: 90
      )

      described_class.new(season).call

      overall_entry = season.singing_season_ranking_entries.find_by!(category: "overall")
      pitch_entry = season.singing_season_ranking_entries.find_by!(category: "pitch")

      expect(overall_entry.title).to eq "今月のトップシンガー"
      expect(overall_entry.badge_key).to eq "monthly_overall_top_1"
      expect(pitch_entry.title).to eq "Pitchリーダー"
      expect(pitch_entry.badge_key).to eq "monthly_pitch_top_1"
    end

    it "再実行時に対象カテゴリを置き換えて重複しないこと" do
      diagnosis = FactoryBot.create(
        :singing_diagnosis, :completed, :ranking_participant,
        customer: customer_a,
        diagnosed_at: Time.zone.local(2026, 5, 10, 12, 0, 0),
        overall_score: 80
      )
      FactoryBot.create(
        :singing_season_ranking_entry,
        singing_ranking_season: season,
        customer: customer_a,
        singing_diagnosis: diagnosis,
        category: "overall",
        rank: 99,
        score: 1
      )

      described_class.new(season).call
      described_class.new(season).call

      overall_entries = season.singing_season_ranking_entries.where(category: "overall")
      expect(overall_entries.count).to eq 1
      expect(overall_entries.first.rank).to eq 1
      expect(overall_entries.first.score).to eq 80
    end

    it "growth など対象外カテゴリは削除しないこと" do
      diagnosis = FactoryBot.create(
        :singing_diagnosis, :completed, :ranking_participant,
        customer: customer_a,
        diagnosed_at: Time.zone.local(2026, 5, 10, 12, 0, 0),
        overall_score: 80
      )
      growth_entry = FactoryBot.create(
        :singing_season_ranking_entry,
        singing_ranking_season: season,
        customer: customer_a,
        singing_diagnosis: diagnosis,
        category: "growth",
        rank: 1,
        score: 10
      )

      described_class.new(season).call

      expect(season.singing_season_ranking_entries.find_by(category: "growth")).to eq growth_entry
    end
  end
end
