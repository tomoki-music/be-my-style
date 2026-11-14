class Business::HomesController < ApplicationController
  skip_before_action :authenticate_customer!, only: [:top]

  # ログイン前は紹介ページ(従来のヘッダー)のまま、ログイン後だけ Business の枠を使う。
  layout -> { customer_signed_in? ? "business" : "application" }

  # 未ログインでは紹介ページを出し、プロジェクトの名前・件数を含め何も取得しない。
  # コミュニティは参加済み・未参加を問わず Business コミュニティ全件(音楽コミュニティは出さない)、
  # プロジェクトは本人の参加先だけを出す。参加済みだけの一覧はメニューの「コミュニティ」(communities#index)。
  def top
    return unless customer_signed_in?

    @home_communities = Business::CommunityDirectory.browsable(current_customer, page: params[:community_page], per: Homes::MyCommunities::PER_PAGE)
    # NAKAMA のホームだけ、本人が参加済みのプライベートも出す(音楽側のホーム / は出さない)。
    @my_projects = Homes::MyProjects.call(current_customer, page: params[:project_page], with_images: true, include_private: true)
  end
end
