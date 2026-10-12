class Notification < ApplicationRecord
  LEARNING_ACTION_TYPES = {
    reminder: "learning_reminder",
    teacher_action: "learning_teacher_action",
    weekly_summary: "learning_weekly_summary"
  }.freeze

  default_scope -> { order(created_at: :desc) }
  belongs_to :event, optional: true
  belongs_to :comment, optional: true
  belongs_to :activity, optional: true
  belongs_to :community, optional: true
  belongs_to :post, optional: true
  belongs_to :project, optional: true
  belongs_to :chat_message, optional: true

  belongs_to :visitor, class_name: 'Customer', foreign_key: 'visitor_id', optional: true
  belongs_to :visited, class_name: 'Customer', foreign_key: 'visited_id', optional: true

  BUSINESS_POST_ACTIONS = %w[like message].freeze
  BUSINESS_COMMUNITY_ACTIONS = %w[request accept].freeze
  BUSINESS_PROJECT_ACTIONS = %w[project_created project_joined project_message].freeze

  # Business(NAKAMA)の通知一覧・ベルで扱う通知。music のチャット・イベント等は含めない。
  # request / accept は music のコミュニティでも使う action 名なので、Business コミュニティ分だけに絞る。
  # follow はフォロー関係がドメイン共通のため含める。
  def self.for_business
    business_community_ids = Community.where(domain_id: Domain.where(name: "business").select(:id)).select(:id)

    where(action: BUSINESS_POST_ACTIONS).where.not(post_id: nil)
      .or(where(action: "follow"))
      .or(where(action: BUSINESS_COMMUNITY_ACTIONS, community_id: business_community_ids))
      .or(where(action: BUSINESS_PROJECT_ACTIONS).where.not(project_id: nil))
  end
end
