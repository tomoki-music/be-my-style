module Learning
  class LineConnection < ApplicationRecord
    self.table_name = "learning_line_connections"

    STATUSES = %w[pending connected disabled].freeze
    TOKEN_TTL = 24.hours

    belongs_to :customer
    belongs_to :learning_student, class_name: "LearningStudent", optional: true

    validates :line_user_id, presence: true, if: :connected?
    validates :status, presence: true, inclusion: { in: STATUSES }
    validates :connect_token, uniqueness: true, allow_blank: true

    scope :connected, -> { where(status: "connected") }
    scope :with_active_token, -> { where.not(connect_token: nil).where("expires_at > ?", Time.current) }

    def self.find_by_active_token(token)
      return nil if token.blank?

      with_active_token.find_by(connect_token: token)
    end

    def issue_connect_token!(expires_in: TOKEN_TTL)
      update!(
        connect_token: self.class.generate_unique_token,
        expires_at: expires_in.from_now,
        status: "pending"
      )
    end

    def token_active?
      connect_token.present? && expires_at.present? && expires_at.future?
    end

    def token_expired?
      connect_token.present? && expires_at.present? && !expires_at.future?
    end

    def connected?
      status == "connected"
    end

    def complete_connection!(line_user_id:, display_name: nil)
      raise ActiveRecord::RecordNotFound unless token_active?

      update!(
        line_user_id: line_user_id,
        display_name: display_name,
        status: "connected",
        connected_at: Time.current,
        connect_token: nil,
        expires_at: nil
      )
    end

    def self.generate_unique_token
      loop do
        token = SecureRandom.urlsafe_base64(32)
        break token unless exists?(connect_token: token)
      end
    end
  end
end
