module Singing
  class SingerRankService
    Rank = Struct.new(:level, :label, :icon, :color_class, :min_xp, keyword_init: true)

    RANKS = [
      { level: 1, label: "見習いシンガー",     icon: "🎵", color_class: "singer-rank--rookie",   min_xp: 0    },
      { level: 2, label: "駆け出しシンガー",   icon: "🌱", color_class: "singer-rank--beginner", min_xp: 100  },
      { level: 3, label: "上昇気流",           icon: "🌊", color_class: "singer-rank--rising",   min_xp: 300  },
      { level: 4, label: "本格派",             icon: "⭐", color_class: "singer-rank--solid",    min_xp: 600  },
      { level: 5, label: "実力派",             icon: "🌟", color_class: "singer-rank--skilled",  min_xp: 1000 },
      { level: 6, label: "ステージの申し子",   icon: "🎤", color_class: "singer-rank--stage",    min_xp: 1500 },
      { level: 7, label: "一流シンガー",       icon: "💫", color_class: "singer-rank--elite",    min_xp: 2500 },
      { level: 8, label: "レジェンドシンガー", icon: "👑", color_class: "singer-rank--legend",   min_xp: 4000 }
    ].map { |attrs| Rank.new(**attrs) }.freeze

    MAX_LEVEL = RANKS.last.level

    def self.rank_for(xp)
      new(xp).rank_for
    end

    def self.next_rank_for(xp)
      new(xp).next_rank
    end

    def self.xp_progress(xp)
      new(xp).xp_progress
    end

    def self.level_for_xp(xp)
      rank_for(xp).level
    end

    def initialize(xp)
      @xp = xp.to_i
    end

    def rank_for
      RANKS.reverse.find { |rank| @xp >= rank.min_xp } || RANKS.first
    end

    def next_rank
      current_level = rank_for.level
      return nil if current_level >= MAX_LEVEL

      RANKS.find { |rank| rank.level == current_level + 1 }
    end

    def xp_progress
      current = rank_for
      nxt = next_rank

      return { percent: 100, xp_in_tier: 0, xp_for_tier: 0, xp_to_next: 0 } if nxt.nil?

      xp_in_tier   = @xp - current.min_xp
      xp_for_tier  = nxt.min_xp - current.min_xp
      xp_to_next   = nxt.min_xp - @xp
      percent       = (xp_in_tier.to_f / xp_for_tier * 100).round.clamp(0, 100)

      { percent: percent, xp_in_tier: xp_in_tier, xp_for_tier: xp_for_tier, xp_to_next: xp_to_next }
    end
  end
end
