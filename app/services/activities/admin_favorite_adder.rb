# 管理画面から、運営が所有する会員アカウント(OWNED_CUSTOMER_IDS)の「いいね」を活動報告へ追加する。
#
# - 会員はサーバー側で決める(フォームから受け取るのは件数だけ)。候補は ID の昇順。
# - 存在しない会員・退会済み/無効な会員・投稿者本人・登録済みの会員は候補から除く。
# - 記事の行をロックしてから候補を再計算し、選んだ件数を確保できなければ何も登録しない。
#   通常の「いいね」(Favorite.add_unique)も同じ行ロックを取るため、同時に処理されても重複しない。
# - 通知・メールは作らない(会員本人の操作ではないため)。
module Activities
  class AdminFavoriteAdder
    OWNED_CUSTOMER_IDS = (2..10).to_a.freeze
    MAX_COUNT = OWNED_CUSTOMER_IDS.size
    LOG_TAG = "[Activities::AdminFavoriteAdder]".freeze

    Result = Struct.new(:added_ids, :error, keyword_init: true) do
      def success?
        error.nil?
      end
    end

    def self.call(activity_id:, count:, admin:)
      new(activity_id: activity_id, count: count, admin: admin).call
    end

    # 一覧表示用。activities ごとの追加可能な会員 ID を、クエリ2本でまとめて求める。
    def self.candidate_ids_by_activity(activities)
      eligible_ids = eligible_customer_ids
      favorited = Favorite.where(activity_id: activities.map(&:id), customer_id: eligible_ids)
                          .distinct.pluck(:activity_id, :customer_id)
                          .group_by(&:first).transform_values { |pairs| pairs.map(&:last) }

      activities.to_h do |activity|
        [activity.id, eligible_ids - [activity.customer_id] - favorited.fetch(activity.id, [])]
      end
    end

    def self.candidate_ids(activity)
      candidate_ids_by_activity([activity]).fetch(activity.id)
    end

    def self.eligible_customer_ids
      Customer.where(id: OWNED_CUSTOMER_IDS, is_deleted: false)
              .then { |scope| Customer.withdrawn_at_column? ? scope.where(withdrawn_at: nil) : scope }
              .order(:id).pluck(:id)
    end

    def initialize(activity_id:, count:, admin:)
      @activity_id = activity_id
      @count = parse_count(count)
      @admin = admin
    end

    def call
      return failure("追加件数は1〜#{MAX_COUNT}件で選んでください。") if @count.nil?

      added_ids = nil
      error = nil
      ActiveRecord::Base.transaction do
        activity = Activity.lock.find_by(id: @activity_id)
        if activity.nil?
          error = "活動報告が見つかりません。"
          raise ActiveRecord::Rollback
        end

        candidates = self.class.candidate_ids(activity)
        if candidates.size < @count
          error = candidates.empty? ? "追加可能なアカウントがありません。" : "追加可能なアカウントは残り#{candidates.size}件です。いいねは追加していません。"
          raise ActiveRecord::Rollback
        end

        added_ids = candidates.first(@count)
        added_ids.each { |customer_id| Favorite.create!(activity_id: activity.id, customer_id: customer_id) }
      end

      return failure(error) if error

      Rails.logger.info("#{LOG_TAG} added admin_id=#{@admin&.id} activity_id=#{@activity_id} customer_ids=#{added_ids.join(',')}")
      Result.new(added_ids: added_ids, error: nil)
    end

    private

    def parse_count(value)
      count = Integer(value.to_s, 10)
      count.between?(1, MAX_COUNT) ? count : nil
    rescue ArgumentError
      nil
    end

    def failure(message)
      Result.new(added_ids: [], error: message)
    end
  end
end
