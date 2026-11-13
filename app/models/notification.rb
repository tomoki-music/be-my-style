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
  # Business スレッドへの投稿の通知(project_message)。旧データは NULL(プロジェクト単位の通知)。
  belongs_to :project_chat, optional: true

  # Business::ProjectThreads::NotifyPost が立てる。この通知の保存がコミットされた後にだけメールを登録する
  # (巻き戻った通知・一意制約で弾かれた重複ではメールを登録しない)。
  attr_accessor :deliver_project_chat_mail
  after_create_commit :enqueue_project_chat_mail, if: :deliver_project_chat_mail

  belongs_to :visitor, class_name: 'Customer', foreign_key: 'visitor_id', optional: true
  belongs_to :visited, class_name: 'Customer', foreign_key: 'visited_id', optional: true

  # 退会済みの会員へは新しい通知を作らない。呼び出し側の多くは `notification.save if notification.valid?` のため、
  # ここで弾けば通知ごとに判定を書かなくても止まる。宛先は DB から読み直して判定する(画面を開いた後の退会にも対応)。
  validate :visited_customer_must_be_notifiable, on: :create

  BUSINESS_POST_ACTIONS = %w[like message].freeze
  BUSINESS_COMMUNITY_ACTIONS = %w[request accept].freeze
  BUSINESS_PROJECT_ACTIONS = %w[project_created project_joined project_message project_request project_accept].freeze

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

  # Business の「画面内の通知」をオフにしていた間の通知(hidden_in_app)は、ベル・通知一覧に出さない。
  # オンに戻しても、オフの間の通知は出さない(オンに戻す前からある通知は従来どおり出る)。
  scope :shown_in_app, -> { where(hidden_in_app: false) }

  private

  def visited_customer_must_be_notifiable
    return if visited_id.blank? # visited_id 自体の必須チェックは DB の NOT NULL に任せる(既存どおり)
    return if Customer.notifiable_id?(visited_id)

    errors.add(:visited, "は退会済みのため通知できません")
  end

  # メールの登録に失敗しても、投稿と画面内の通知は保存済みのまま残す(投稿した人の画面をエラーにしない)。
  # 再実行しても通知は作り直さないため、このメールは送られない。調査できるよう通知 ID を記録する。
  def enqueue_project_chat_mail
    BusinessProjectChatMailer.with(notification_id: id).thread_post_mail.deliver_later
  rescue StandardError => e
    Rails.logger.error("[BusinessProjectChatMailer] enqueue failed notification_id=#{id} #{e.class}: #{e.message}")
  end
end
