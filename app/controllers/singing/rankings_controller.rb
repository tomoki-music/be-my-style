class Singing::RankingsController < Singing::BaseController
  def index
    @rankings = Singing::RankingQuery.overall
  end
end
