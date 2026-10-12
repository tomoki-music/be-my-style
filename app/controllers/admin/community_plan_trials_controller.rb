class Admin::CommunityPlanTrialsController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_community

  # plan_restrictions_waived だけを更新する。コミュニティの他項目や関連(オーナー・チャットルーム)には触れない。
  def update
    unless @community.business_domain?
      redirect_to admin_community_path(@community), alert: "#{helpers.plan_trial_label}はBusinessコミュニティのみ設定できます。"
      return
    end

    waived = ActiveModel::Type::Boolean.new.cast(params.dig(:community, :plan_restrictions_waived)) || false

    if @community.update(plan_restrictions_waived: waived)
      redirect_to admin_community_path(@community, anchor: "plan-trial"), notice: helpers.plan_trial_saved_message(@community)
    else
      redirect_to admin_community_path(@community, anchor: "plan-trial"), alert: "設定を保存できませんでした。"
    end
  end

  private

  def set_community
    @community = Community.find(params[:community_id])
  end
end
