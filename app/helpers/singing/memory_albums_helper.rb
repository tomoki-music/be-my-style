module Singing
  module MemoryAlbumsHelper
    TYPE_LABELS = {
      year_recap:      "Year Recap",
      monthly_wrapped: "Monthly Wrapped",
      singer_story:    "Singer Story"
    }.freeze

    def album_item_type_label(type)
      TYPE_LABELS[type.to_sym] || type.to_s.humanize
    end
  end
end
