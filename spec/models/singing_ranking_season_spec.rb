require 'rails_helper'

RSpec.describe SingingRankingSeason, type: :model do
  describe 'バリデーション' do
    subject(:season) { FactoryBot.build(:singing_ranking_season) }

    it '有効なファクトリーであること' do
      expect(season).to be_valid
    end

    it 'name が必須であること' do
      season.name = nil
      expect(season).not_to be_valid
      expect(season.errors[:name]).to be_present
    end

    it 'starts_on が必須であること' do
      season.starts_on = nil
      expect(season).not_to be_valid
      expect(season.errors[:starts_on]).to be_present
    end

    it 'ends_on が必須であること' do
      season.ends_on = nil
      expect(season).not_to be_valid
      expect(season.errors[:ends_on]).to be_present
    end

    it 'status が必須であること' do
      season.status = nil
      expect(season).not_to be_valid
      expect(season.errors[:status]).to be_present
    end

    it 'season_type が必須であること' do
      season.season_type = nil
      expect(season).not_to be_valid
      expect(season.errors[:season_type]).to be_present
    end

    it 'status は draft / active / closed のみ許可すること' do
      season.status = "invalid"
      expect(season).not_to be_valid
    end

    it 'season_type は monthly のみ許可すること' do
      season.season_type = "weekly"
      expect(season).not_to be_valid
    end

    it 'ends_on が starts_on より前の場合は無効であること' do
      season.starts_on = Date.current
      season.ends_on   = Date.current - 1.day
      expect(season).not_to be_valid
      expect(season.errors[:ends_on]).to be_present
    end

    it 'ends_on が starts_on と同日の場合は有効であること' do
      season.starts_on = Date.current
      season.ends_on   = Date.current
      expect(season).to be_valid
    end
  end

  describe 'アソシエーション' do
    it 'singing_season_ranking_entries を持つこと' do
      expect(SingingRankingSeason.reflect_on_association(:singing_season_ranking_entries).macro).to eq :has_many
    end
  end

  describe 'スコープ' do
    let!(:active_season) { FactoryBot.create(:singing_ranking_season, :current) }
    let!(:closed_season) { FactoryBot.create(:singing_ranking_season, :closed) }
    let!(:draft_season)  { FactoryBot.create(:singing_ranking_season, :draft) }

    describe '.active' do
      it 'status が active のシーズンのみ返すこと' do
        expect(SingingRankingSeason.active).to include(active_season)
        expect(SingingRankingSeason.active).not_to include(closed_season, draft_season)
      end
    end

    describe '.closed' do
      it 'status が closed のシーズンのみ返すこと' do
        expect(SingingRankingSeason.closed).to include(closed_season)
        expect(SingingRankingSeason.closed).not_to include(active_season, draft_season)
      end
    end

    describe '.current' do
      it '今日の日付が starts_on〜ends_on に含まれる active シーズンを返すこと' do
        expect(SingingRankingSeason.current).to include(active_season)
      end

      it '期間外のシーズンは返さないこと' do
        expect(SingingRankingSeason.current).not_to include(closed_season, draft_season)
      end

      it 'active でも期間が今日を含まないシーズンは返さないこと' do
        future_active = FactoryBot.create(
          :singing_ranking_season,
          status: "active",
          starts_on: 1.month.from_now.to_date,
          ends_on: 2.months.from_now.to_date
        )
        expect(SingingRankingSeason.current).not_to include(future_active)
      end
    end

    describe '.recent' do
      it 'starts_on の降順で返すこと' do
        seasons = SingingRankingSeason.recent.where(id: [active_season.id, closed_season.id])
        expect(seasons.first).to eq(active_season)
        expect(seasons.last).to eq(closed_season)
      end
    end
  end
end
