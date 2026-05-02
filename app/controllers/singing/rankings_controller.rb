class Singing::RankingsController < Singing::BaseController
  def index
    @rankings = fetch_rankings
  end

  private

  def fetch_rankings
    seen_customers = {}
    result = []

    SingingDiagnosis
      .completed
      .where(ranking_opt_in: true)
      .where.not(overall_score: nil)
      .includes(:customer)
      .order(overall_score: :desc, id: :desc)
      .each do |diagnosis|
        next if seen_customers[diagnosis.customer_id]

        seen_customers[diagnosis.customer_id] = true
        result << diagnosis
      end

    result
  end
end
