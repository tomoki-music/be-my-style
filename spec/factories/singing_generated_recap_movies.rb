FactoryBot.define do
  factory :singing_generated_recap_movie do
    customer
    year   { Time.current.year }
    status { :pending }

    trait :processing do
      status { :processing }
    end

    trait :completed do
      status       { :completed }
      generated_at { Time.current }
      expires_at   { 30.days.from_now }

      after(:build) do |movie|
        movie.video_file.attach(
          io: StringIO.new("MP4"),
          filename: "recap_#{movie.year}.mp4",
          content_type: "video/mp4"
        )
      end
    end

    trait :failed do
      status        { :failed }
      error_message { "Remotion render failed" }
    end

    trait :expired do
      status     { :expired }
      expires_at { 1.day.ago }
    end
  end
end
