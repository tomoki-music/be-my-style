FactoryBot.define do
  factory :caption_video do
    association :customer
    sequence(:title) { |n| "テロップ動画#{n}" }
    status { "uploaded" }
    duration { 60.0 }
    width { 1920 }
    height { 1080 }
    aspect_ratio { "16:9" }

    transient do
      source_video_filename { "sample.mp4" }
      source_video_content_type { "video/mp4" }
    end

    # 実際のMP4/MOVバイナリは不要(ffprobe/ffmpeg呼び出しはservice/job specでモックする)。
    # モデルレベルのバリデーションが見るのはActive Storageのcontent_type/byte_sizeのみ。
    after(:build) do |caption_video, evaluator|
      caption_video.source_video.attach(
        io: StringIO.new("dummy video content"),
        filename: evaluator.source_video_filename,
        content_type: evaluator.source_video_content_type
      )
    end

    trait :mov do
      source_video_filename { "sample.mov" }
      source_video_content_type { "video/quicktime" }
    end

    trait :ready_for_edit do
      status { "ready_for_edit" }
    end

    trait :rendering do
      status { "rendering" }
    end

    trait :completed do
      status { "completed" }
    end

    trait :failed do
      status { "failed" }
      error_message { "テスト用の失敗メッセージ" }
    end
  end
end
