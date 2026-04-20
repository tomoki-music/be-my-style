module Stampable
  extend ActiveSupport::Concern

  STAMP_OPTIONS = {
    "clap" => "👏 ナイス！",
    "fire" => "🔥 アツい！",
    "music" => "🎵 参加したい！",
    "thanks" => "🙏 ありがとう！",
    "love" => "😍 最高！"
  }.freeze

  included do
    validates :stamp_type, inclusion: { in: STAMP_OPTIONS.keys }, allow_blank: true
  end

  def stamp_label
    STAMP_OPTIONS[stamp_type.to_s]
  end

  def stamped?
    stamp_type.present?
  end
end
