module Singing
  class AwardRecapMovieBadgesService
    BADGE_KEY_BY_KIND = {
      "x"         => "recap_movie_first_share",
      "download"  => "recap_movie_first_download",
      "instagram" => "recap_movie_instagram_share"
    }.freeze

    def self.call(recap_movie, kind)
      new(recap_movie, kind).call
    end

    def initialize(recap_movie, kind)
      @recap_movie = recap_movie
      @customer    = recap_movie.customer
      @kind        = kind
    end

    def call
      badge_key = BADGE_KEY_BY_KIND[@kind]
      return unless badge_key

      award!(badge_key)
    end

    private

    attr_reader :recap_movie, :customer, :kind

    def award!(badge_key)
      SingingAchievementBadge.create!(
        customer:   customer,
        badge_key:  badge_key,
        earned_at:  Time.current,
        metadata:   build_metadata(badge_key)
      )
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
      Rails.logger.info(
        "[AwardRecapMovieBadgesService] skip badge=#{badge_key} customer=#{customer.id} reason=#{e.class}"
      )
    end

    def build_metadata(badge_key)
      defn = SingingAchievementBadge::BADGE_DEFINITIONS[badge_key]
      {
        schema_version:   1,
        badge_key:        badge_key,
        badge_label:      defn[:label],
        earned_at_label:  Time.current.strftime("%Y年%-m月%-d日"),
        recap_movie_id:   recap_movie.id,
        recap_movie_year: recap_movie.year,
        share_kind:       kind
      }.compact
    end
  end
end
