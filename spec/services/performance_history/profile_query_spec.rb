require 'rails_helper'

RSpec.describe PerformanceHistory::ProfileQuery do
  let(:customer) { FactoryBot.create(:customer) }
  let(:community) { FactoryBot.create(:community) }

  # :event factoryのデフォルト日時は固定の過去日時(2023年)のため、そのまま使えば終了済みイベントになる。
  let(:past_event) { FactoryBot.create(:event, :event_with_songs, community: community) }
  let(:upcoming_event) do
    FactoryBot.create(
      :event, :event_with_songs, community: community,
      event_start_time: 2.days.from_now, event_end_time: 3.days.from_now, event_entry_deadline: 1.day.from_now
    )
  end

  let(:song) { FactoryBot.create(:song, event: past_event, song_name: "テスト曲", artist_name: "テストアーティスト") }
  let(:join_part) { FactoryBot.create(:join_part, song: song, join_part_name: "Vocal") }

  def call
    described_class.call(customer)
  end

  it '終了済みイベントのエントリーをSummaryとして返すこと' do
    FactoryBot.create(:join_part_customer, join_part: join_part, customer: customer)

    summaries = call

    expect(summaries.size).to eq 1
    summary = summaries.first
    expect(summary.song_master).to eq song.song_master
    expect(summary.part_name).to eq "Vocal"
    expect(summary.count).to eq 1
    expect(summary.entries.first.event).to eq past_event
  end

  it '開催前イベントのエントリーは含めないこと' do
    upcoming_song = FactoryBot.create(:song, event: upcoming_event, song_name: "テスト曲", artist_name: "テストアーティスト")
    upcoming_part = FactoryBot.create(:join_part, song: upcoming_song, join_part_name: "Vocal")
    FactoryBot.create(:join_part_customer, join_part: upcoming_part, customer: customer)

    expect(call).to eq []
  end

  it '同じ曲・パートを複数イベントで演奏した場合、演奏回数へ反映されること' do
    other_event = FactoryBot.create(:event, :event_with_songs, community: community)
    other_song = FactoryBot.create(:song, event: other_event, song_name: "テスト曲", artist_name: "テストアーティスト")
    other_part = FactoryBot.create(:join_part, song: other_song, join_part_name: "Vocal")

    FactoryBot.create(:join_part_customer, join_part: join_part, customer: customer)
    FactoryBot.create(:join_part_customer, join_part: other_part, customer: customer)

    summaries = call

    expect(summaries.size).to eq 1
    expect(summaries.first.count).to eq 2
  end

  it '「曲名（アーティスト名）」形式と「曲名」+アーティスト欄形式の演奏を、同一曲の実績としてまとめること' do
    embedded_event = FactoryBot.create(:event, :event_with_songs, community: community)
    embedded_song = FactoryBot.create(:song, event: embedded_event, song_name: "マリーゴールド（あいみょん）", artist_name: nil)
    embedded_part = FactoryBot.create(:join_part, song: embedded_song, join_part_name: "Vocal")

    split_event = FactoryBot.create(:event, :event_with_songs, community: community)
    split_song = FactoryBot.create(:song, event: split_event, song_name: "マリーゴールド", artist_name: "あいみょん")
    split_part = FactoryBot.create(:join_part, song: split_song, join_part_name: "Vocal")

    FactoryBot.create(:join_part_customer, join_part: embedded_part, customer: customer)
    FactoryBot.create(:join_part_customer, join_part: split_part, customer: customer)

    summaries = call

    expect(summaries.size).to eq 1
    expect(summaries.first.count).to eq 2
  end

  it '新しい順に並ぶこと' do
    older_event = FactoryBot.create(:event, :event_with_songs, community: community, event_start_time: 10.years.ago, event_end_time: 10.years.ago + 1.hour, event_entry_deadline: 10.years.ago - 1.day)
    older_song = FactoryBot.create(:song, event: older_event, song_name: "古い曲")
    older_part = FactoryBot.create(:join_part, song: older_song, join_part_name: "Vocal")
    FactoryBot.create(:join_part_customer, join_part: older_part, customer: customer)

    newer_event = FactoryBot.create(:event, :event_with_songs, community: community, event_start_time: 1.year.ago, event_end_time: 1.year.ago + 1.hour, event_entry_deadline: 1.year.ago - 1.day)
    newer_song = FactoryBot.create(:song, event: newer_event, song_name: "新しい曲")
    newer_part = FactoryBot.create(:join_part, song: newer_song, join_part_name: "Vocal")
    FactoryBot.create(:join_part_customer, join_part: newer_part, customer: customer)

    summaries = call

    expect(summaries.map { |s| s.song_master.song_name }).to eq %w[新しい曲 古い曲]
  end

  it '同一イベント・同一曲・同一パートを重複計上しないこと' do
    duplicate_part = FactoryBot.create(:join_part, song: song, join_part_name: "Vocal")
    FactoryBot.create(:join_part_customer, join_part: join_part, customer: customer)
    FactoryBot.create(:join_part_customer, join_part: duplicate_part, customer: customer)

    summaries = call

    expect(summaries.size).to eq 1
    expect(summaries.first.count).to eq 1
  end

  it '自己申告のCustomerSongPartは含めないこと' do
    FactoryBot.create(:customer_song_part, customer: customer, song: song, song_master: song.song_master, part_name: "Guitar")

    expect(call).to eq []
  end

  it 'データがない場合、空配列を返すこと' do
    expect(call).to eq []
  end

  it 'song_master_idが未解決のSongは対象に含めないこと(バックフィル未実施分)' do
    FactoryBot.create(:join_part_customer, join_part: join_part, customer: customer)
    song.update_column(:song_master_id, nil)

    expect(call).to eq []
  end

  describe '旧パート名の正規化' do
    it '安全な旧パート名(Vo等)は現行パート名で集計されること' do
      legacy_part = FactoryBot.create(:join_part, song: song, join_part_name: "Vo")
      FactoryBot.create(:join_part_customer, join_part: legacy_part, customer: customer)

      summaries = call

      expect(summaries.first.part_name).to eq "Vocal"
    end

    it '曖昧な旧パート名(Chorus等)は演奏実績として表示しないこと' do
      legacy_part = FactoryBot.create(:join_part, song: song, join_part_name: "Chorus")
      FactoryBot.create(:join_part_customer, join_part: legacy_part, customer: customer)

      expect(call).to eq []
    end
  end

  it '全イベントをロードせず、終了済みイベントをDB側で絞り込むこと(N+1が全体件数に比例しないこと)' do
    FactoryBot.create(:join_part_customer, join_part: join_part, customer: customer)
    5.times do |i|
      other_event = FactoryBot.create(:event, :event_with_songs, community: community, event_start_time: (i + 1).years.from_now, event_end_time: (i + 1).years.from_now + 1.hour, event_entry_deadline: (i + 1).years.from_now - 1.day)
      other_song = FactoryBot.create(:song, event: other_event)
      other_part = FactoryBot.create(:join_part, song: other_song, join_part_name: "Vocal")
      FactoryBot.create(:join_part_customer, join_part: other_part, customer: customer)
    end

    query_count = 0
    counter = ->(_name, _started, _finished, _unique_id, payload) {
      query_count += 1 if payload[:sql].to_s.match?(/\ASELECT/i)
    }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      described_class.call(customer)
    end

    expect(query_count).to be <= 10
  end
end
