class Singing::HomesController < Singing::BaseController
  def top
    @singing_lp_back_label = "診断履歴を見る"
    @singing_lp_back_path = singing_diagnoses_path
    @singing_lp_hero_back_label = "診断履歴を見る"

    @growth_dashboard = Singing::HomeGrowthDashboardBuilder.call(current_customer) if customer_signed_in?

    render template: "public/lp/singing"
  end
end
