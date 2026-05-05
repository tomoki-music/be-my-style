module Singing
  class RankingQuery
    GrowthEntry = Struct.new(
      :customer, :latest_diagnosis, :previous_diagnosis, :growth_score,
      keyword_init: true
    )

    def self.overall
      new.overall
    end

    def self.position_for(customer_id)
      new.position_for(customer_id)
    end

    def self.growth
      new.growth
    end

    def self.season(range = current_season_range)
      new.season(range)
    end

    def self.season_position_for(customer_id, range = current_season_range)
      new.season_position_for(customer_id, range)
    end

    # Returns the current season range (this calendar month).
    # Override or extend this method to support quarter/event-based seasons.
    def self.current_season_range
      start  = Time.zone.now.beginning_of_month
      finish = Time.zone.now.next_month.beginning_of_month
      start...finish
    end

    # Returns ranked diagnoses (one per customer, highest score first).
    # Includes customer associations for view rendering.
    def overall
      seen = {}
      result = []
      base_scope
        .includes(customer: { profile_image_attachment: :blob })
        .each do |diagnosis|
          next if seen[diagnosis.customer_id]
          seen[diagnosis.customer_id] = true
          result << diagnosis
        end
      result
    end

    # Returns 1-based rank position of the given customer, or nil if not ranked.
    # Uses pluck to avoid loading unnecessary associations.
    def position_for(customer_id)
      return nil if customer_id.blank?

      seen = {}
      rank = 0
      base_scope.pluck(:customer_id).each do |cid|
        next if seen[cid]
        seen[cid] = true
        rank += 1
        return rank if cid == customer_id
      end
      nil
    end

    # Returns GrowthEntry list sorted by score improvement (desc).
    # Only includes customers whose latest ranking_opt_in diagnosis improved
    # over their immediately preceding completed diagnosis.
    # Uses exactly 2 SQL queries (N+1 safe).
    def growth
      # Query 1: latest ranking_opt_in diagnosis per customer (with associations)
      latest_by_customer = {}
      SingingDiagnosis
        .completed
        .where(ranking_opt_in: true)
        .where.not(overall_score: nil)
        .includes(customer: { profile_image_attachment: :blob })
        .order(created_at: :desc, id: :desc)
        .each do |d|
          latest_by_customer[d.customer_id] ||= d
        end

      return [] if latest_by_customer.empty?

      # Query 2: all completed diagnoses for qualifying customers (for prev lookup)
      all_by_customer = SingingDiagnosis
        .completed
        .where.not(overall_score: nil)
        .where(customer_id: latest_by_customer.keys)
        .order(created_at: :desc, id: :desc)
        .group_by(&:customer_id)

      entries = []
      latest_by_customer.each_value do |latest|
        diagnoses = all_by_customer[latest.customer_id] || []

        previous = diagnoses.find do |d|
          d.created_at < latest.created_at ||
            (d.created_at == latest.created_at && d.id < latest.id)
        end

        next unless previous

        growth_score = latest.overall_score - previous.overall_score
        next unless growth_score > 0

        entries << GrowthEntry.new(
          customer: latest.customer,
          latest_diagnosis: latest,
          previous_diagnosis: previous,
          growth_score: growth_score
        )
      end

      entries.sort_by { |e| [-e.growth_score, -(e.latest_diagnosis.diagnosed_at&.to_i || 0)] }
    end

    # Returns ranked diagnoses within the given season range (one per customer,
    # highest in-season score first). Uses diagnosed_at for season filtering.
    # Includes customer associations for view rendering.
    def season(range = self.class.current_season_range)
      seen = {}
      result = []
      SingingDiagnosis
        .completed
        .where(ranking_opt_in: true)
        .where.not(overall_score: nil)
        .where.not(diagnosed_at: nil)
        .where(diagnosed_at: range)
        .includes(customer: { profile_image_attachment: :blob })
        .order(overall_score: :desc, diagnosed_at: :desc, id: :desc)
        .each do |diagnosis|
          next if seen[diagnosis.customer_id]
          seen[diagnosis.customer_id] = true
          result << diagnosis
        end
      result
    end

    # Returns 1-based season rank for the given customer, or nil.
    # Uses pluck to avoid loading unnecessary associations.
    def season_position_for(customer_id, range = self.class.current_season_range)
      return nil if customer_id.blank?

      seen = {}
      rank = 0
      SingingDiagnosis
        .completed
        .where(ranking_opt_in: true)
        .where.not(overall_score: nil)
        .where.not(diagnosed_at: nil)
        .where(diagnosed_at: range)
        .order(overall_score: :desc, diagnosed_at: :desc, id: :desc)
        .pluck(:customer_id)
        .each do |cid|
          next if seen[cid]
          seen[cid] = true
          rank += 1
          return rank if cid == customer_id
        end
      nil
    end

    private

    def base_scope
      SingingDiagnosis
        .completed
        .where(ranking_opt_in: true)
        .where.not(overall_score: nil)
        .order(overall_score: :desc, id: :desc)
    end
  end
end
