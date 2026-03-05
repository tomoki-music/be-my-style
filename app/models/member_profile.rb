class MemberProfile < ApplicationRecord
  belongs_to :customer

  enum music_experience_level: {
    beginner: 0,
    hobby: 1,
    band: 2
  }

  enum engagement_style: {
    casual: 0,
    regular: 1,
    challenge_active: 2,
    undecided: 3
  }

  enum suggested_member_type: {
    enjoy: 0,
    growth: 1,
    challenge_member: 2,
    unclassified: 3
  }

  enum contact_preference: {
    welcome: 0,
    passive: 1,
    no_contact: 2
  }

  def self.suggested_member_type_options
    suggested_member_types.keys.map do |k|
      [I18n.t("enums.member_profile.suggested_member_type.#{k}"), k]
    end
  end
end
