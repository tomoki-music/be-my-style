module Singing
  class AchievementRecapMovieSerializer
    def initialize(result)
      @result = result
    end

    def as_json
      {
        year:           @result.year,
        title:          @result.title,
        subtitle:       @result.subtitle,
        total_duration: @result.total_duration,
        empty:          @result.empty?,
        scenes:         serialize_scenes(@result.scenes)
      }
    end

    private

    def serialize_scenes(scenes)
      scenes.map { |scene| serialize_scene(scene) }
    end

    def serialize_scene(scene)
      {
        index:            scene.index,
        type:             scene.type.to_s,
        title:            scene.title,
        subtitle:         scene.subtitle,
        body:             scene.body,
        duration:         scene.duration,
        emotion:          scene.emotion.to_s,
        background_style: scene.background_style.to_s,
        badge:            serialize_badge(scene.badge)
      }
    end

    def serialize_badge(badge)
      return nil if badge.nil?

      {
        label:       badge.label,
        emoji:       badge.emoji,
        rarity:      badge.rarity.to_s,
        earned_at:   badge.earned_at&.to_date&.iso8601,
        description: badge.description
      }
    end
  end
end
