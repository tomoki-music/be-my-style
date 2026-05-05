module Singing
  class RankingQuery
    def self.overall
      new.overall
    end

    def self.position_for(customer_id)
      new.position_for(customer_id)
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
