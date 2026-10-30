# ログイン後ホーム(/ と /business)の本文。どちらも「自分のコミュニティ」「自分のプロジェクト」の2つの一覧だけにする。
# 一覧ごとにページ番号のパラメータを分け、片方をめくってももう片方のページが変わらないようにする。
module MemberHome
  extend ActiveSupport::Concern

  private

  def load_member_home(with_images: false, business_only: false)
    @my_communities = Homes::MyCommunities.call(current_customer, page: params[:community_page], with_images: with_images, business_only: business_only)
    @my_projects = Homes::MyProjects.call(current_customer, page: params[:project_page], with_images: with_images)
  end
end
