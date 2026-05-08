class Singing::RankingSeasonsController < Singing::BaseController
  # Active season の show で使うリアルタイム集計エントリーの構造体
  LiveSeasonEntry = Struct.new(:rank, :score, :customer, :category, :title, :badge_key, :singing_diagnosis, keyword_init: true)

  def index
    @current_season = SingingRankingSeason.current.first
    @seasons = SingingRankingSeason.recent.where(status: %w[active closed])
  end

  def show
    @season = SingingRankingSeason.find(params[:id])
    season_range = @season.starts_on.beginning_of_day..@season.ends_on.end_of_day

    @entries_by_category = if @season.status == "active"
                              # 開催中シーズン: rankings ページと同じ SingingDiagnosis 直接集計
                              build_live_season_entries(Singing::RankingQuery.season(season_range))
                            else
                              # 終了済みシーズン: 管理集計済みの SingingSeasonRankingEntry を使用
                              @season.singing_season_ranking_entries
                                     .includes(:customer, :singing_diagnosis)
                                     .by_rank
                                     .group_by(&:category)
                            end

    @my_diagnosis_count = SingingDiagnosis
                            .where(customer_id: current_customer.id, status: :completed)
                            .where(diagnosed_at: season_range)
                            .count
  end

  private

  def build_live_season_entries(diagnoses)
    return {} if diagnoses.empty?

    entries = diagnoses.each_with_index.map do |diagnosis, index|
      LiveSeasonEntry.new(
        rank:             index + 1,
        score:            diagnosis.overall_score,
        customer:         diagnosis.customer,
        category:         "overall",
        title:            nil,
        badge_key:        nil,
        singing_diagnosis: diagnosis
      )
    end
    { "overall" => entries }
  end
end
