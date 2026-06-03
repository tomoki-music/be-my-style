module Singing
  class CommunityFeedBuilder
    STREAK_MILESTONE = 7
    FEED_LIMIT       = 10
    LOOKBACK_DAYS    = 30

    FeedItem = Struct.new(
      :type,
      :customer,
      :message,
      :icon,
      :occurred_at,
      keyword_init: true
    )

    CommunityFeed = Struct.new(
      :feed_items,
      keyword_init: true
    )

    def self.call
      new.call
    end

    def call
      items = personal_best_items + streak_milestone_items + challenge_achieved_items + diagnosis_completed_items
      sorted = items.compact.sort_by(&:occurred_at).reverse.first(FEED_LIMIT)
      CommunityFeed.new(feed_items: sorted)
    rescue StandardError
      CommunityFeed.new(feed_items: [])
    end

    private

    def lookback_since
      @lookback_since ||= LOOKBACK_DAYS.days.ago
    end

    # 直近 LOOKBACK_DAYS に診断があった顧客のカラムデータを一括ロード。
    # personal_best / streak の両検出に使い回すため全履歴を取得する。
    def diagnoses_by_customer
      return @diagnoses_by_customer if defined?(@diagnoses_by_customer)

      recent_ids = SingingDiagnosis
        .completed
        .where.not(overall_score: nil)
        .where(created_at: lookback_since..)
        .distinct
        .pluck(:customer_id)

      if recent_ids.empty?
        @customer_lookup       = {}
        @diagnoses_by_customer = {}
        return @diagnoses_by_customer
      end

      rows = SingingDiagnosis
        .completed
        .where.not(overall_score: nil)
        .where(customer_id: recent_ids)
        .order(:customer_id, :created_at, :id)
        .pluck(:customer_id, :overall_score, :created_at)

      @customer_lookup       = Customer.where(id: recent_ids).index_by(&:id)
      @diagnoses_by_customer = rows.group_by { |row| row[0] }
    end

    def customer_lookup
      diagnoses_by_customer
      @customer_lookup || {}
    end

    def personal_best_items
      items = []
      diagnoses_by_customer.each do |customer_id, rows|
        customer = customer_lookup[customer_id]
        next if customer.nil?

        current_best = nil
        rows.each do |row|
          score      = row[1]
          created_at = row[2]

          if current_best.nil?
            current_best = score
            next
          end

          if score > current_best
            current_best = score
            next if created_at < lookback_since

            items << FeedItem.new(
              type:        :personal_best,
              customer:    customer,
              message:     "自己ベスト更新",
              icon:        "⭐",
              occurred_at: created_at
            )
          end
        end
      end
      items
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
      []
    end

    def streak_milestone_items
      items = []
      diagnoses_by_customer.each do |customer_id, rows|
        customer = customer_lookup[customer_id]
        next if customer.nil?

        dates = rows.map { |row| row[2].to_date }.uniq.sort
        next if dates.size < STREAK_MILESTONE

        streak = 1
        dates.each_cons(2) do |prev_date, curr_date|
          if curr_date == prev_date + 1.day
            streak += 1
            if streak == STREAK_MILESTONE
              occurred_at = rows
                .select { |row| row[2].to_date == curr_date }
                .map { |row| row[2] }
                .max
              next unless occurred_at && occurred_at >= lookback_since

              items << FeedItem.new(
                type:        :streak_milestone,
                customer:    customer,
                message:     "#{STREAK_MILESTONE}日継続達成",
                icon:        "🔥",
                occurred_at: occurred_at
              )
            end
          else
            streak = 1
          end
        end
      end
      items
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
      []
    end

    def challenge_achieved_items
      SingingAiChallengeProgress
        .where(completed: true)
        .where(completed_at: lookback_since..)
        .includes(:customer)
        .order(completed_at: :desc)
        .limit(20)
        .filter_map do |progress|
          next if progress.customer.nil?
          next if progress.completed_at.nil?

          FeedItem.new(
            type:        :challenge_achieved,
            customer:    progress.customer,
            message:     "Challenge達成",
            icon:        "🏆",
            occurred_at: progress.completed_at
          )
        end
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
      []
    end

    def diagnosis_completed_items
      SingingDiagnosis
        .completed
        .where.not(overall_score: nil)
        .where(created_at: lookback_since..)
        .includes(:customer)
        .order(created_at: :desc)
        .limit(50)
        .filter_map do |d|
          next if d.customer.nil?

          FeedItem.new(
            type:        :diagnosis_completed,
            customer:    d.customer,
            message:     "新しい診断に挑戦しました",
            icon:        "🎤",
            occurred_at: d.created_at
          )
        end
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
      []
    end
  end
end
