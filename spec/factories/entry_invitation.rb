FactoryBot.define do
  factory :entry_invitation do
    association :customer
    association :requested_by_customer, factory: :customer
    sent_at { Time.current }
    status { :pending }

    transient do
      event_for_invitation { FactoryBot.create(:event, :event_with_songs) }
    end

    event { event_for_invitation }
    song { event.songs.first || FactoryBot.create(:song, event: event) }
    join_part { FactoryBot.create(:join_part, song: song, join_part_name: "Vocal") }
  end
end
