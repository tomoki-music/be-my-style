require 'rails_helper'

RSpec.describe SongPerformances::ExperiencedCustomersByEventQuery, type: :model do
  let(:community) { FactoryBot.create(:community) }
  let(:past_event) { FactoryBot.create(:event, :event_with_songs, community: community, event_end_time: 2.days.ago, event_start_time: 3.days.ago, event_entry_deadline: 4.days.ago) }
  let(:current_event) { FactoryBot.create(:event, :event_with_songs, community: community, event_end_time: 3.days.from_now, event_start_time: 2.days.from_now, event_entry_deadline: 1.day.from_now) }
  let(:song_master) { FactoryBot.create(:song_master, song_name: "同じ曲") }
  let(:past_song) { FactoryBot.create(:song, event: past_event, song_name: "同じ曲") }
  let(:current_song) { FactoryBot.create(:song, event: current_event, song_name: "同じ曲") }
  let(:experienced_customer) { FactoryBot.create(:customer) }
  let(:withdrawn_customer) { FactoryBot.create(:customer, is_deleted: true) }

  before do
    past_song.update!(song_master: song_master)
    current_song.update!(song_master: song_master)
  end

  it '対象曲・パートが一致する過去の演奏実績を持つcustomerを返すこと' do
    FactoryBot.create(:song_performance, customer: experienced_customer, song: past_song, song_master: song_master, event: past_event, join_part: nil, part_name: "Vocal")

    result = described_class.call(current_event.reload)

    expect(result[[song_master.id, "Vocal"]]).to include(experienced_customer)
  end

  it '現在閲覧中のイベント自身の実績は経験者に含めないこと' do
    FactoryBot.create(:song_performance, customer: experienced_customer, song: current_song, song_master: song_master, event: current_event, join_part: nil, part_name: "Vocal")

    result = described_class.call(current_event.reload)

    expect(result[[song_master.id, "Vocal"]]).not_to include(experienced_customer)
  end

  it '退会済みcustomerは経験者に含めないこと' do
    FactoryBot.create(:song_performance, customer: withdrawn_customer, song: past_song, song_master: song_master, event: past_event, join_part: nil, part_name: "Vocal")

    result = described_class.call(current_event.reload)

    expect(result[[song_master.id, "Vocal"]]).not_to include(withdrawn_customer)
  end

  it '同じcustomerが複数回演奏していても重複表示しないこと' do
    other_past_event = FactoryBot.create(:event, :event_with_songs, community: community, event_end_time: 5.days.ago, event_start_time: 6.days.ago, event_entry_deadline: 7.days.ago)
    other_song = FactoryBot.create(:song, event: other_past_event, song_name: "同じ曲", song_master: song_master)
    FactoryBot.create(:song_performance, customer: experienced_customer, song: past_song, song_master: song_master, event: past_event, join_part: nil, part_name: "Vocal")
    FactoryBot.create(:song_performance, customer: experienced_customer, song: other_song, song_master: song_master, event: other_past_event, join_part: nil, part_name: "Vocal")

    result = described_class.call(current_event.reload)

    expect(result[[song_master.id, "Vocal"]].count { |c| c.id == experienced_customer.id }).to eq 1
  end

  it '該当データがない場合は空を返すこと' do
    result = described_class.call(current_event.reload)
    expect(result[[song_master.id, "Vocal"]]).to eq []
  end
end
