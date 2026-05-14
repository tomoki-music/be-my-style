module Singing
  class XpGranter
    BASE_XP = 50
    SCORE_BONUS_MAX = 50

    Result = Struct.new(:xp_gained, :leveled_up, :old_rank, :new_rank, :new_xp, keyword_init: true)

    def self.call(diagnosis)
      new(diagnosis).call
    end

    def initialize(diagnosis)
      @diagnosis = diagnosis
      @customer  = diagnosis.customer
    end

    def call
      return nil unless @customer && @diagnosis.completed?

      xp_gained  = calculate_xp
      old_xp     = @customer.singing_xp
      old_rank   = SingerRankService.rank_for(old_xp)
      new_xp     = old_xp + xp_gained
      new_rank   = SingerRankService.rank_for(new_xp)
      leveled_up = new_rank.level > old_rank.level
      new_level  = new_rank.level

      @customer.update_columns(singing_xp: new_xp, singing_level: new_level)

      Result.new(
        xp_gained:  xp_gained,
        leveled_up: leveled_up,
        old_rank:   old_rank,
        new_rank:   new_rank,
        new_xp:     new_xp
      )
    end

    private

    def calculate_xp
      score_bonus = ((@diagnosis.overall_score.to_f / 100) * SCORE_BONUS_MAX).round
      BASE_XP + score_bonus
    end
  end
end
