require 'rails_helper'

RSpec.describe PerformanceHistory::ExperiencedCustomersQuery do
  let(:community) { FactoryBot.create(:community) }
  let(:experienced_customer) { FactoryBot.create(:customer, name: "経験太郎") }

  let(:past_event) do
    FactoryBot.create(
      :event, :event_with_songs, community: community,
      event_start_time: 3.days.ago, event_end_time: 2.days.ago, event_entry_deadline: 4.days.ago
    )
  end
  let(:current_event) do
    FactoryBot.create(
      :event, :event_with_songs, community: community,
      event_start_time: 2.days.from_now, event_end_time: 3.days.from_now, event_entry_deadline: 1.day.from_now
    )
  end

  let(:past_song) { FactoryBot.create(:song, event: past_event, song_name: "共通曲", artist_name: "共通アーティスト") }
  let(:current_song) { FactoryBot.create(:song, event: current_event, song_name: "共通曲", artist_name: "共通アーティスト") }
  let(:past_vocal_part) { FactoryBot.create(:join_part, song: past_song, join_part_name: "Vocal") }
  let(:current_vocal_part) { FactoryBot.create(:join_part, song: current_song, join_part_name: "Vocal") }

  before { current_vocal_part }

  def call
    described_class.call(current_event)
  end

  it '終了済みイベントの別Songエントリーを、同じsong_master_id・part_nameのキーで返すこと' do
    FactoryBot.create(:join_part_customer, join_part: past_vocal_part, customer: experienced_customer)

    result = call

    expect(result[[current_song.song_master_id, "Vocal"]]).to contain_exactly(experienced_customer)
  end

  it '開催前イベントのエントリーは対象に含めないこと' do
    upcoming_event = FactoryBot.create(
      :event, :event_with_songs, community: community,
      event_start_time: 2.days.from_now, event_end_time: 3.days.from_now, event_entry_deadline: 1.day.from_now
    )
    upcoming_song = FactoryBot.create(:song, event: upcoming_event, song_name: "共通曲", artist_name: "共通アーティスト")
    upcoming_part = FactoryBot.create(:join_part, song: upcoming_song, join_part_name: "Vocal")
    FactoryBot.create(:join_part_customer, join_part: upcoming_part, customer: experienced_customer)

    expect(call).to eq({})
  end

  it '表示中イベント自身のエントリーは対象に含めないこと' do
    FactoryBot.create(:join_part_customer, join_part: current_vocal_part, customer: experienced_customer)

    expect(call).to eq({})
  end

  it '退会済みユーザーは対象に含めないこと' do
    withdrawn = FactoryBot.create(:customer, is_deleted: true)
    FactoryBot.create(:join_part_customer, join_part: past_vocal_part, customer: withdrawn)

    expect(call).to eq({})
  end

  it '取消済み(削除済み)のエントリーは対象に含めないこと' do
    join_part_customer = FactoryBot.create(:join_part_customer, join_part: past_vocal_part, customer: experienced_customer)
    join_part_customer.destroy!

    expect(call).to eq({})
  end

  it '同じユーザーが複数の過去イベントで演奏していても重複しないこと' do
    other_past_event = FactoryBot.create(
      :event, :event_with_songs, community: community,
      event_start_time: 6.days.ago, event_end_time: 5.days.ago, event_entry_deadline: 7.days.ago
    )
    other_song = FactoryBot.create(:song, event: other_past_event, song_name: "共通曲", artist_name: "共通アーティスト")
    other_part = FactoryBot.create(:join_part, song: other_song, join_part_name: "Vocal")

    FactoryBot.create(:join_part_customer, join_part: past_vocal_part, customer: experienced_customer)
    FactoryBot.create(:join_part_customer, join_part: other_part, customer: experienced_customer)

    result = call

    expect(result[[current_song.song_master_id, "Vocal"]].size).to eq 1
  end

  describe '旧パート名の正規化' do
    it '安全な旧パート名(Vo等)は現行パートの経験者として一致すること' do
      legacy_part = FactoryBot.create(:join_part, song: past_song, join_part_name: "Vo")
      FactoryBot.create(:join_part_customer, join_part: legacy_part, customer: experienced_customer)

      result = call

      expect(result[[current_song.song_master_id, "Vocal"]]).to contain_exactly(experienced_customer)
    end

    it '曖昧な旧パート名(Chorus等)は勝手に一致させないこと' do
      legacy_part = FactoryBot.create(:join_part, song: past_song, join_part_name: "Chorus")
      FactoryBot.create(:join_part_customer, join_part: legacy_part, customer: experienced_customer)

      result = call

      expect(result.values.flatten).not_to include(experienced_customer)
    end
  end

  it '該当データがない場合は空のHashを返すこと' do
    expect(call).to eq({})
  end

  describe '.key_for(Controller/Viewと共有する検索キーの組み立て)' do
    it 'song_master_idと生のパート名から、#call内部と同じ正規化済みキーを返すこと' do
      expect(described_class.key_for(current_song.song_master_id, "Vo")).to eq([current_song.song_master_id, "Vocal"])
    end

    it '既に現行の選択肢そのものであれば、そのままキーとして返すこと' do
      expect(described_class.key_for(current_song.song_master_id, "Vocal")).to eq([current_song.song_master_id, "Vocal"])
    end

    it 'song_master_idがnilの場合、安全にnilを返すこと' do
      expect(described_class.key_for(nil, "Vocal")).to be_nil
    end

    it '安全に正規化できないパート名の場合、nilを返すこと' do
      expect(described_class.key_for(current_song.song_master_id, "Chorus")).to be_nil
    end
  end

  it '曲数xパート数分のN+1を発生させないこと(クエリ件数が曲・パート数に比例しないこと)' do
    # current_eventと同じsong_master(同一曲名・アーティスト名)に紐づく過去エントリーを、
    # 曲3件xパート3件(=9エントリー)分用意しても、SQLクエリ件数が一定であることを確認する。
    current_song # song_master_idを確定させる
    3.times do |i|
      other_past_event = FactoryBot.create(
        :event, :event_with_songs, community: community,
        event_start_time: (10 + i).days.ago, event_end_time: (9 + i).days.ago, event_entry_deadline: (11 + i).days.ago
      )
      song = FactoryBot.create(:song, event: other_past_event, song_name: "共通曲", artist_name: "共通アーティスト")
      %w[Vocal Guitar Bass].each do |part_name|
        part = FactoryBot.create(:join_part, song: song, join_part_name: part_name)
        FactoryBot.create(:join_part_customer, join_part: part, customer: FactoryBot.create(:customer))
      end
    end

    count_selects = lambda do
      count = 0
      counter = ->(_name, _started, _finished, _unique_id, payload) {
        count += 1 if payload[:sql].to_s.match?(/\ASELECT/i)
      }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { described_class.call(current_event) }
      count
    end

    baseline = count_selects.call
    # 曲・パート数を増やしても一定(SQL2回 + プロフィール画像の Active Storage 先読み分)
    expect(baseline).to be <= 5

    # 候補人数を増やしても Active Storage のクエリが人数に比例しないこと
    other_past_event = FactoryBot.create(
      :event, :event_with_songs, community: community,
      event_start_time: 20.days.ago, event_end_time: 19.days.ago, event_entry_deadline: 21.days.ago
    )
    extra_song = FactoryBot.create(:song, event: other_past_event, song_name: "共通曲", artist_name: "共通アーティスト")
    extra_part = FactoryBot.create(:join_part, song: extra_song, join_part_name: "Vocal")
    3.times { FactoryBot.create(:join_part_customer, join_part: extra_part, customer: FactoryBot.create(:customer)) }

    expect(count_selects.call).to eq baseline
  end

  it 'プロフィール画像を人数に依らず先読みする(Active Storage の N+1 を防ぐ)' do
    current_song
    3.times do |i|
      past = FactoryBot.create(
        :event, :event_with_songs, community: community,
        event_start_time: (30 + i).days.ago, event_end_time: (29 + i).days.ago, event_entry_deadline: (31 + i).days.ago
      )
      song = FactoryBot.create(:song, event: past, song_name: "共通曲", artist_name: "共通アーティスト")
      part = FactoryBot.create(:join_part, song: song, join_part_name: "Vocal")
      FactoryBot.create(:join_part_customer, join_part: part, customer: FactoryBot.create(:customer))
    end

    customers = described_class.call(current_event).values.flatten

    expect(customers).to be_present
    customers.each do |customer|
      expect(customer.association(:profile_image_attachment)).to be_loaded
    end
  end
end
