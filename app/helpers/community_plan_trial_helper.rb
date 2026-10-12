# 「有料機能を無料でお試し」(communities.plan_restrictions_waived)の表示文言を、
# システム管理画面と Business コミュニティ画面で揃えるためのヘルパー。
module CommunityPlanTrialHelper
  def plan_trial_label
    "有料機能を無料でお試し"
  end

  def plan_trial_description
    "ONにすると、このBusinessコミュニティ内で有料プランの対象機能を無料で利用できます。"
  end

  # 実際に解除される機能。もともと free で使える機能は「解除」ではないので出さない。
  def plan_trial_unlocked_features
    Community::PLAN_RESTRICTION_WAIVABLE_FEATURES.filter_map do |feature_key|
      next if Customer::FEATURE_RULES.fetch(feature_key).include?("free")

      gate = ApplicationController::FEATURE_CATALOG.fetch(feature_key)
      "#{gate[:title]}（通常は#{gate[:required_plan].capitalize}プラン以上）"
    end
  end

  # 変更できるのは管理画面と同じ Devise の Admin でログイン中のシステム管理者だけ。
  # Customer 側の権限(is_owner の admin・コミュニティのオーナー / 管理権限)では変更できない。
  def plan_trial_editable?
    admin_signed_in?
  end

  def plan_trial_readonly_note
    "この設定はシステム管理者のみ変更できます。"
  end

  def plan_trial_status_label(community)
    community.plan_restrictions_waived? ? "ON（無料お試し中）" : "OFF"
  end

  def plan_trial_saved_message(community)
    "「#{plan_trial_label}」を#{community.plan_restrictions_waived? ? 'ON' : 'OFF'}にして保存しました。"
  end
end
