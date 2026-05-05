require 'rails_helper'

RSpec.describe SingingSeasonRankingEntry, type: :model do
  let(:season)   { FactoryBot.create(:singing_ranking_season) }
  let(:customer) { FactoryBot.create(:customer, domain_name: "singing") }

  describe 'バリデーション' do
    subject(:entry) { FactoryBot.build(:singing_season_ranking_entry, singing_ranking_season: season, customer: customer) }

    it '有効なファクトリーであること' do
      expect(entry).to be_valid
    end

    it 'singing_ranking_season が必須であること' do
      entry.singing_ranking_season = nil
      expect(entry).not_to be_valid
    end

    it 'customer が必須であること' do
      entry.customer = nil
      expect(entry).not_to be_valid
    end

    it 'category が必須であること' do
      entry.category = nil
      expect(entry).not_to be_valid
    end

    it 'score が必須であること' do
      entry.score = nil
      expect(entry).not_to be_valid
    end

    it 'rank が必須であること' do
      entry.rank = nil
      expect(entry).not_to be_valid
    end

    it 'score は 0 以上の整数であること' do
      entry.score = -1
      expect(entry).not_to be_valid
    end

    it 'rank は 1 以上の整数であること' do
      entry.rank = 0
      expect(entry).not_to be_valid
    end

    it 'category は定義済みの値のみ許可すること' do
      entry.category = "invalid_category"
      expect(entry).not_to be_valid
    end

    it 'overall は有効な category であること' do
      entry.category = "overall"
      expect(entry).to be_valid
    end

    it 'growth は有効な category であること' do
      entry.category = "growth"
      expect(entry).to be_valid
    end

    describe 'ユニーク制約' do
      before do
        FactoryBot.create(:singing_season_ranking_entry,
                          singing_ranking_season: season,
                          customer: customer,
                          category: "overall",
                          rank: 1,
                          score: 80)
      end

      it '同一 season + customer + category で重複登録できないこと' do
        duplicate = FactoryBot.build(:singing_season_ranking_entry,
                                     singing_ranking_season: season,
                                     customer: customer,
                                     category: "overall",
                                     rank: 2,
                                     score: 75)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:customer_id]).to be_present
      end

      it 'カテゴリが異なれば同一 season + customer でも登録できること' do
        different_category = FactoryBot.build(:singing_season_ranking_entry,
                                              singing_ranking_season: season,
                                              customer: customer,
                                              category: "growth",
                                              rank: 1,
                                              score: 10)
        expect(different_category).to be_valid
      end

      it 'シーズンが異なれば同一 customer + category でも登録できること' do
        other_season = FactoryBot.create(:singing_ranking_season)
        different_season = FactoryBot.build(:singing_season_ranking_entry,
                                            singing_ranking_season: other_season,
                                            customer: customer,
                                            category: "overall",
                                            rank: 1,
                                            score: 80)
        expect(different_season).to be_valid
      end
    end
  end

  describe 'アソシエーション' do
    it 'singing_ranking_season に belongs_to すること' do
      expect(SingingSeasonRankingEntry.reflect_on_association(:singing_ranking_season).macro).to eq :belongs_to
    end

    it 'customer に belongs_to すること' do
      expect(SingingSeasonRankingEntry.reflect_on_association(:customer).macro).to eq :belongs_to
    end

    it 'singing_diagnosis に optional で belongs_to すること' do
      reflection = SingingSeasonRankingEntry.reflect_on_association(:singing_diagnosis)
      expect(reflection.macro).to eq :belongs_to
      expect(reflection.options[:optional]).to eq true
    end
  end

  describe 'スコープ' do
    let!(:entry1) { FactoryBot.create(:singing_season_ranking_entry, singing_ranking_season: season, rank: 3, score: 70) }
    let!(:entry2) { FactoryBot.create(:singing_season_ranking_entry, singing_ranking_season: season, rank: 1, score: 90,
                                       customer: FactoryBot.create(:customer, domain_name: "singing")) }
    let!(:entry3) { FactoryBot.create(:singing_season_ranking_entry, singing_ranking_season: season, rank: 2, score: 80,
                                       customer: FactoryBot.create(:customer, domain_name: "singing")) }

    describe '.by_rank' do
      it 'rank の昇順で返すこと' do
        ordered = SingingSeasonRankingEntry.by_rank.where(singing_ranking_season: season)
        expect(ordered.map(&:rank)).to eq [1, 2, 3]
      end
    end

    describe '.overall' do
      it 'category が overall のエントリーのみ返すこと' do
        pitch_entry = FactoryBot.create(:singing_season_ranking_entry,
                                        singing_ranking_season: season,
                                        customer: FactoryBot.create(:customer, domain_name: "singing"),
                                        category: "pitch",
                                        rank: 1,
                                        score: 85)
        overall_entries = SingingSeasonRankingEntry.overall.where(singing_ranking_season: season)
        expect(overall_entries).to include(entry1, entry2, entry3)
        expect(overall_entries).not_to include(pitch_entry)
      end
    end

    describe '.for_category' do
      it '指定したカテゴリのエントリーのみ返すこと' do
        growth_entry = FactoryBot.create(:singing_season_ranking_entry,
                                         singing_ranking_season: season,
                                         customer: FactoryBot.create(:customer, domain_name: "singing"),
                                         category: "growth",
                                         rank: 1,
                                         score: 15)
        expect(SingingSeasonRankingEntry.for_category("growth")).to include(growth_entry)
        expect(SingingSeasonRankingEntry.for_category("growth")).not_to include(entry1)
      end
    end
  end
end
