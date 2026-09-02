require 'rails_helper'

RSpec.describe PerformanceRankings::RankingQuery do
  include ActiveSupport::Testing::TimeHelpers

  let(:music_domain) { Domain.find_or_create_by!(name: "music") }
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:community) { create(:community, domain: music_domain, name: "Aコミュニティ") }
  let(:other_community) { create(:community, domain: music_domain, name: "Bコミュニティ") }

  # Event は songs presence 必須のため :event_with_songs でダミー曲を1つ持たせる。
  # ダミー曲はパートを持たないので集計には影響しない。
  def ended_event(start_time: 20.days.ago, in_community: nil)
    create(
      :event, :event_with_songs,
      community: in_community || community,
      event_start_time: start_time,
      event_end_time: start_time + 2.hours,
      event_entry_deadline: start_time - 1.day
    )
  end

  def upcoming_event(in_community: nil)
    create(
      :event, :event_with_songs,
      community: in_community || community,
      event_start_time: 10.days.from_now,
      event_end_time: 10.days.from_now + 2.hours,
      event_entry_deadline: 5.days.from_now
    )
  end

  # event 内の 1 曲に、customer を part で参加させる。song を渡すと同じ曲へ追加できる。
  def perform!(event, customer:, song_name: "デフォルト曲", artist_name: "アーティスト", part: "Vocal", song: nil)
    song ||= create(:song, event: event, song_name: song_name, artist_name: artist_name)
    join_part = create(:join_part, song: song, join_part_name: part)
    create(:join_part_customer, join_part: join_part, customer: customer)
    song
  end

  def period(preset: "all", **opts)
    PerformanceRankings::Period.new(preset: preset, **opts)
  end

  def query(**opts)
    described_class.new(**opts)
  end

  describe "集計対象" do
    it "終了済みイベントの演奏だけを集計すること" do
      alice = create(:customer, name: "Alice")
      perform!(ended_event, customer: alice, song_name: "終了曲")
      perform!(upcoming_event, customer: alice, song_name: "開催前曲")

      rows = query.rows
      expect(rows.size).to eq 1
      expect(rows.first.play_count).to eq 1
    end

    it "開催中(終了していない)イベントは集計しないこと" do
      alice = create(:customer, name: "Alice")
      ongoing = create(
        :event, :event_with_songs, community: community,
        event_start_time: 1.hour.ago, event_end_time: 1.hour.from_now, event_entry_deadline: 2.hours.ago
      )
      perform!(ongoing, customer: alice)

      expect(query.rows).to be_empty
    end

    it "退会済みユーザーはランキングに載せないこと" do
      withdrawn = create(:customer, name: "Withdrawn", is_deleted: true)
      perform!(ended_event, customer: withdrawn)

      expect(query.rows).to be_empty
    end

    it "SongMasterに紐づかない曲は集計しないこと" do
      alice = create(:customer, name: "Alice")
      song = perform!(ended_event, customer: alice, song_name: "マスターなし")
      song.update_columns(song_master_id: nil)

      expect(query.rows).to be_empty
    end

    it "正規化できないパートは集計しないこと" do
      alice = create(:customer, name: "Alice")
      perform!(ended_event, customer: alice, song_name: "コーラス曲", part: "Chorus")

      expect(query.rows).to be_empty
    end

    it "musicドメイン以外のコミュニティのイベントは集計しないこと" do
      biz_community = create(:community, domain: business_domain, name: "ビジネス")
      alice = create(:customer, name: "Alice")
      perform!(ended_event(in_community: biz_community), customer: alice)

      expect(query.rows).to be_empty
    end
  end

  describe "演奏数ランキング(kind: performances)" do
    it "既定の kind であること" do
      expect(query.kind).to eq "performances"
      expect(query(kind: "unknown").kind).to eq "performances"
    end

    it "行が customer 単位で、演奏数が多い順に並ぶこと" do
      heavy = create(:customer, name: "Heavy")
      light = create(:customer, name: "Light")
      event = ended_event
      perform!(event, customer: heavy, song_name: "曲1", part: "Vocal")
      perform!(event, customer: heavy, song_name: "曲2", part: "Guitar")
      perform!(event, customer: light, song_name: "曲1", part: "Bass")

      rows = query(kind: "performances").rows
      expect(rows.map { |r| r.customer.name }).to eq %w[Heavy Light]
      expect(rows.map(&:play_count)).to eq [2, 1]
      expect(rows.map(&:customer_id)).to eq [heavy.id, light.id]
    end

    it "同一ユーザー・同一イベント・同一曲・同一パートの重複エントリーは1演奏として数えること" do
      alice = create(:customer, name: "Alice")
      song = perform!(ended_event, customer: alice, song_name: "重複曲", part: "Vocal")
      dup_part = create(:join_part, song: song, join_part_name: "Vocal")
      create(:join_part_customer, join_part: dup_part, customer: alice)

      expect(query.rows.first.play_count).to eq 1
    end

    it "同一イベント・同一曲でも担当パートが異なれば別々の演奏として数えること" do
      alice = create(:customer, name: "Alice")
      song = perform!(ended_event, customer: alice, song_name: "兼任曲", part: "Vocal")
      perform!(song.event, customer: alice, song: song, part: "Guitar")

      row = query.rows.first
      expect(row.play_count).to eq 2
      expect(row.event_count).to eq 1
      expect(row.song_count).to eq 1
      expect(row.part_breakdown["Vocal"]).to eq 1
      expect(row.part_breakdown["Guitar"]).to eq 1
    end

    it "異なる演奏楽曲数(song_count)を SongMaster 単位で返すこと" do
      alice = create(:customer, name: "Alice")
      perform!(ended_event(start_time: 30.days.ago), customer: alice, song_name: "リピート曲", artist_name: "X")
      perform!(ended_event(start_time: 10.days.ago), customer: alice, song_name: "リピート曲", artist_name: "X")
      perform!(ended_event(start_time: 5.days.ago), customer: alice, song_name: "別曲", artist_name: "Y")

      row = query.rows.first
      expect(row.play_count).to eq 3
      expect(row.song_count).to eq 2
    end

    it "レガシーなパート名(Gt / ギター)を正規化して内訳に合算すること" do
      alice = create(:customer, name: "Alice")
      event = ended_event
      perform!(event, customer: alice, song_name: "曲1", part: "Gt")
      perform!(event, customer: alice, song_name: "曲2", part: "ギター")
      perform!(event, customer: alice, song_name: "曲3", part: "Guitar")

      expect(query.rows.first.part_breakdown["Guitar"]).to eq 3
    end

    it "競技順位が演奏数だけを基準に採番されること(1,2,2,4)" do
      event = ended_event
      { "A" => 3, "B" => 2, "C" => 2, "D" => 1 }.each do |name, n|
        customer = create(:customer, name: name)
        n.times { |i| perform!(event, customer: customer, song_name: "#{name}#{i}") }
      end

      rows = query(kind: "performances").rows
      expect(rows.map { |r| r.customer.name }).to eq %w[A B C D]
      expect(rows.map(&:rank)).to eq [1, 2, 2, 4]
    end

    it "同率時は参加イベント数の降順、さらに同率なら customer_id 昇順で安定すること" do
      wide_event_a = ended_event(start_time: 20.days.ago)
      wide_event_b = ended_event(start_time: 15.days.ago)
      one_event = ended_event(start_time: 10.days.ago)

      # first: 2イベントで各1演奏 / second: 1イベントで2演奏。演奏数はどちらも2。
      first = create(:customer, name: "First")
      second = create(:customer, name: "Second")
      perform!(wide_event_a, customer: first, song_name: "f1")
      perform!(wide_event_b, customer: first, song_name: "f2")
      perform!(one_event, customer: second, song_name: "s1")
      perform!(one_event, customer: second, song_name: "s2")

      rows = query(kind: "performances").rows
      expect(rows.map { |r| r.customer.name }).to eq %w[First Second]
      expect(rows.map(&:rank)).to eq [1, 1]
    end
  end

  describe "参加イベント数ランキング(kind: events)" do
    it "有効な演奏実績を持つ異なるイベント数で並ぶこと" do
      organizer = create(:customer, name: "Organizer")
      single = create(:customer, name: "Single")

      3.times do |i|
        event = ended_event(start_time: (20 - i).days.ago)
        perform!(event, customer: organizer, song_name: "o#{i}")
      end
      event = ended_event(start_time: 3.days.ago)
      perform!(event, customer: single, song_name: "s1", part: "Vocal")
      perform!(event, customer: single, song_name: "s2", part: "Guitar")

      rows = query(kind: "events").rows
      expect(rows.map { |r| r.customer.name }).to eq %w[Organizer Single]
      expect(rows.map(&:event_count)).to eq [3, 1]
      expect(rows.map(&:play_count)).to eq [3, 2]
    end

    it "同一イベントで複数曲・複数パートを演奏しても参加イベント数は1件であること" do
      alice = create(:customer, name: "Alice")
      event = ended_event
      perform!(event, customer: alice, song_name: "曲1", part: "Vocal")
      perform!(event, customer: alice, song_name: "曲2", part: "Guitar")
      perform!(event, customer: alice, song_name: "曲3", part: "Bass")

      row = query(kind: "events").rows.first
      expect(row.event_count).to eq 1
      expect(row.play_count).to eq 3
    end

    it "競技順位が参加イベント数だけを基準に採番されること(1,2,2,4)" do
      { "A" => 3, "B" => 2, "C" => 2, "D" => 1 }.each do |name, n|
        customer = create(:customer, name: name)
        n.times do |i|
          event = ended_event(start_time: (20 - i).days.ago)
          perform!(event, customer: customer, song_name: "#{name}#{i}")
        end
      end

      rows = query(kind: "events").rows
      expect(rows.map { |r| r.customer.name }).to eq %w[A B C D]
      expect(rows.map(&:rank)).to eq [1, 2, 2, 4]
    end

    it "同率時は演奏数の降順で並ぶこと" do
      busy = create(:customer, name: "Busy")
      calm = create(:customer, name: "Calm")
      event_a = ended_event(start_time: 20.days.ago)
      event_b = ended_event(start_time: 10.days.ago)

      [event_a, event_b].each do |event|
        perform!(event, customer: busy, song_name: "b-#{event.id}-1", part: "Vocal")
        perform!(event, customer: busy, song_name: "b-#{event.id}-2", part: "Guitar")
        perform!(event, customer: calm, song_name: "c-#{event.id}-1", part: "Vocal")
      end

      rows = query(kind: "events").rows
      expect(rows.map { |r| r.customer.name }).to eq %w[Busy Calm]
      expect(rows.map(&:event_count)).to eq [2, 2]
      expect(rows.map(&:rank)).to eq [1, 1]
    end
  end

  describe "軸の切り替え" do
    it "同じデータでも kind により順位が変わること" do
      wide = create(:customer, name: "Wide")   # 3イベント各1演奏
      deep = create(:customer, name: "Deep")   # 1イベント4演奏

      3.times do |i|
        event = ended_event(start_time: (20 - i).days.ago)
        perform!(event, customer: wide, song_name: "w#{i}")
      end
      deep_event = ended_event(start_time: 2.days.ago)
      %w[Vocal Guitar Bass Drums].each_with_index do |part, i|
        perform!(deep_event, customer: deep, song_name: "d#{i}", part: part)
      end

      by_performances = query(kind: "performances").rows
      expect(by_performances.map { |r| r.customer.name }).to eq %w[Deep Wide]

      by_events = query(kind: "events").rows
      expect(by_events.map { |r| r.customer.name }).to eq %w[Wide Deep]
    end
  end

  describe "各行の展開詳細" do
    it "現在ページの各 Row に detail(参加イベント / 演奏楽曲 / 担当パート)が割り当てられること" do
      alice = create(:customer, name: "Alice")
      event = ended_event
      perform!(event, customer: alice, song_name: "詳細曲", artist_name: "Z", part: "Vocal")

      row = query.rows.first
      expect(row.detail).to be_present
      expect(row.detail.events.map(&:name)).to include(event.event_name)
      expect(row.detail.songs.map(&:name)).to include("詳細曲")
      expect(row.detail.parts).to include(["Vocal", 1])
    end
  end

  describe "集計範囲の切り替え" do
    it "コミュニティ内はそのコミュニティのイベントだけを集計すること" do
      alice = create(:customer, name: "Alice")
      perform!(ended_event(in_community: community), customer: alice, song_name: "A社曲")
      perform!(ended_event(in_community: other_community), customer: alice, song_name: "B社曲")

      global = query(scope: "all").rows.first
      scoped = query(scope: "community", community_id: community.id).rows.first
      expect(global.play_count).to eq 2
      expect(scoped.play_count).to eq 1
    end

    it "存在しない community_id でコミュニティ内を指定しても全体扱いにフォールバックすること" do
      alice = create(:customer, name: "Alice")
      perform!(ended_event, customer: alice)

      q = query(scope: "community", community_id: "999999")
      expect(q.scope).to eq "all"
      expect(q.rows.first.play_count).to eq 1
    end

    it "musicドメイン以外の community_id は採用しないこと" do
      biz = create(:community, domain: business_domain, name: "ビジネス")
      q = query(scope: "community", community_id: biz.id)
      expect(q.scope).to eq "all"
      expect(q.community_id).to be_nil
    end
  end

  describe "集計期間(Asia/Tokyo基準・イベント開催日)" do
    it "今月指定は当月開催のイベントだけを集計すること" do
      travel_to(Time.zone.local(2026, 9, 15, 12)) do
        alice = create(:customer, name: "Alice")
        perform!(ended_event(start_time: Time.zone.local(2026, 9, 3, 12)), customer: alice, song_name: "9月曲")
        perform!(ended_event(start_time: Time.zone.local(2026, 8, 20, 12)), customer: alice, song_name: "8月曲")

        expect(query(period: period(preset: "this_month")).rows.first.play_count).to eq 1
      end
    end

    it "カスタム期間は開始日と終了日の両端を含むこと" do
      alice = create(:customer, name: "Alice")
      perform!(ended_event(start_time: Time.zone.local(2025, 3, 1, 0, 0, 0)), customer: alice, song_name: "開始日曲")
      perform!(ended_event(start_time: Time.zone.local(2025, 3, 31, 23, 0, 0)), customer: alice, song_name: "終了日曲")
      perform!(ended_event(start_time: Time.zone.local(2025, 4, 1, 0, 30, 0)), customer: alice, song_name: "範囲外曲")

      rows = query(period: period(preset: "custom", start_on: "2025-03-01", end_on: "2025-03-31")).rows
      expect(rows.first.play_count).to eq 2
    end

    it "開始日が終了日より後のカスタム期間は集計せず period_invalid? を返すこと" do
      alice = create(:customer, name: "Alice")
      perform!(ended_event, customer: alice)

      q = query(period: period(preset: "custom", start_on: "2025-03-31", end_on: "2025-03-01"))
      expect(q.period_invalid?).to be true
      expect(q.rows).to be_empty
    end
  end

  describe "不正なパラメータ" do
    it "想定外の kind / scope / community_id でも例外にならず既定値で動くこと" do
      alice = create(:customer, name: "Alice")
      perform!(ended_event, customer: alice)

      q = query(kind: "'; DROP TABLE songs; --", scope: "everywhere", community_id: "abc")
      expect { q.rows }.not_to raise_error
      expect(q.kind).to eq "performances"
      expect(q.scope).to eq "all"
      expect(q.community_id).to be_nil
    end

    it "該当データ0件でも例外にならず空を返すこと" do
      expect(query(period: period(preset: "custom", start_on: "1990-01-01", end_on: "1990-12-31")).rows).to be_empty
    end
  end

  describe "ページネーション" do
    it "per件ごとにページングされ、順位は全体を通した競技順位になること" do
      event = ended_event
      5.times do |i|
        customer = create(:customer, name: "P#{i}")
        (5 - i).times { |j| perform!(event, customer: customer, song_name: "P#{i}-#{j}") }
      end

      page2 = query(per: 2, page: 2).rows
      expect(page2.size).to eq 2
      expect(page2.map(&:rank)).to eq [3, 4]
    end

    it "詳細取得は現在ページの customer に限定されること" do
      event = ended_event
      5.times do |i|
        customer = create(:customer, name: "P#{i}")
        (5 - i).times { |j| perform!(event, customer: customer, song_name: "P#{i}-#{j}") }
      end

      page1 = query(per: 2, page: 1).rows
      expect(page1.map { |r| r.detail.present? }).to all(be true)
    end
  end
end
