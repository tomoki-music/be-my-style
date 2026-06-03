class Singing::HomesController < Singing::BaseController
  skip_before_action :authenticate_customer!, only: [:top]
  skip_before_action :ensure_singing_access!, only: [:top]

  def top
    @singing_lp_back_label = "成長記録を見る"
    @singing_lp_back_path = singing_diagnoses_path
    @singing_lp_hero_back_label = "成長記録を見る"

    home_customer = customer_signed_in? ? current_customer : nil
    challenge_experience = Singing::ChallengeExperienceBuilder.call(home_customer)
    @music_community_home = Singing::MusicCommunityHomeBuilder.call(
      home_customer,
      challenge_experience: challenge_experience
    )
    @growth_dashboard = Singing::HomeGrowthDashboardBuilder.call(current_customer) if customer_signed_in?

    render template: "public/lp/singing"
  end
end
