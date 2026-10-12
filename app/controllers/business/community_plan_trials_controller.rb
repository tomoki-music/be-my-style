class Business::CommunityPlanTrialsController < ApplicationController
  before_action :set_community
  before_action :ensure_system_admin!

  # 制限判定用フラグのみ更新する。契約プラン・課金情報・投稿などの保存済みデータには触れない。
  def update
    waived = ActiveModel::Type::Boolean.new.cast(params.dig(:community, :plan_restrictions_waived)) || false

    if @community.update(plan_restrictions_waived: waived)
      redirect_to business_community_path(@community, anchor: "plan-trial"), notice: helpers.plan_trial_saved_message(@community)
    else
      redirect_to business_community_path(@community), alert: "設定を保存できませんでした。"
    end
  end

  private

  def set_community
    @community = Community.find_by!(
      id: params[:community_id],
      domain_id: @current_domain.id
    )
  end

  # 管理画面(Admin::CommunityPlanTrialsController)と同じく Devise の Admin セッションで判定する。
  # コミュニティのオーナー・管理権限や Customer の is_owner(admin) では変更させない。
  def ensure_system_admin!
    return if admin_signed_in?

    redirect_to business_community_path(@community), alert: "この設定はシステム管理者のみ変更できます。"
  end
end
