FactoryBot.define do
  factory :singing_share_image do
    customer
    capture_target { "yearly-growth" }
    status { :pending }
    expires_at { 7.days.from_now }
    generated_at { Time.current }
    metadata { { title: "2026年 歌声成長レポート", share_text: "#BeMyStyleSinging" } }

    trait :completed do
      status { :completed }

      after(:build) do |share_image|
        share_image.image.attach(
          io: StringIO.new("PNG"),
          filename: "yearly-growth.png",
          content_type: "image/png"
        )
      end
    end
  end
end
