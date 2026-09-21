FactoryBot.define do
  factory :caption_video do
    association :customer
    sequence(:title) { |n| "テロップ動画#{n}" }
    status { "uploaded" }
    duration { 60.0 }
    width { 1920 }
    height { 1080 }
    aspect_ratio { "16:9" }

    # 実際のMP4バイナリは不要(ffprobe/ffmpeg呼び出しはservice/job specでモックする)。
    # モデルレベルのバリデーションが見るのはActive Storageのcontent_type/byte_sizeのみ。
    after(:build) do |caption_video|
      caption_video.source_video.attach(
        io: StringIO.new("dummy video content"),
        filename: "sample.mp4",
        content_type: "video/mp4"
      )
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
