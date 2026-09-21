FactoryBot.define do
  factory :video_caption do
    association :caption_video
    sequence(:display_order)
    start_time { 0.0 }
    end_time { 2.0 }
    text { "テストテロップ" }
    caption_type { "normal" }
    position { "bottom_center" }
  end
end
