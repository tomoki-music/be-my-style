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

    it "musicドメイン以外のコミュニティのイベントは集計しないこと" do
      biz_community = create(:community, domain: business_domain, name: "ビジネス")
      alice = create(:customer, name: "Alice")
      perform!(ended_event(in_community: biz_community), customer: alice)

      expect(query.rows).to be_empty
    end
  end

  describe "総演奏回数(kind: total)" do
    it "演奏回数が多い順に並ぶこと" do
      heavy = create(:customer, name: "Heavy")
      light = create(:customer, name: "Light")
      event = ended_event
      perform!(event, customer: heavy, song_name: "曲1", part: "Vocal")
      perform!(event, customer: heavy, song_name: "曲2", part: "Guitar")
      perform!(event, customer: light, song_name: "曲1", part: "Bass")

      rows = query(kind: "total").rows
      expect(rows.map { |r| r.customer.name }).to eq %w[Heavy Light]
      expect(rows.map(&:play_count)).to eq [2, 1]
    end

    it "同一イベント・同一曲・同一パートの重複エントリーを二重計上しないこと" do
      alice = create(:customer, name: "Alice")
      song = perform!(ended_event, customer: alice, song_name: "重複曲", part: "Vocal")
      # 同じ曲に同名パートをもう1つ作り、同じ人をエントリーさせる(データ不整合の再現)。
      dup_part = create(:join_part, song: song, join_part_name: "Vocal")
      create(:join_part_customer, join_part: dup_part, customer: alice)

      expect(query.rows.first.play_count).to eq 1
    end

    it "パート別の内訳を返すこと" do
      alice = create(:customer, name: "Alice")
      event = ended_event
      perform!(event, customer: alice, song_name: "曲A", part: "Vocal")
      perform!(event, customer: alice, song_name: "曲B", part: "Vocal")
      perform!(event, customer: alice, song_name: "曲C", part: "Guitar")

      row = query.rows.first
      expect(row.part_breakdown["Vocal"]).to eq 2
      expect(row.part_breakdown["Guitar"]).to eq 1
      expect(row.primary_part).to eq "Vocal"
    end
  end

  describe "演奏楽曲数(kind: songs)" do
    it "同じSongMasterの曲を複数回演奏しても1曲として数えること" do
      alice = create(:customer, name: "Alice")
      perform!(ended_event(start_time: 30.days.ago), customer: alice, song_name: "リピート曲", artist_name: "X")
      perform!(ended_event(start_time: 10.days.ago), customer: alice, song_name: "リピート曲", artist_name: "X")

      row = query(kind: "songs").rows.first
      expect(row.song_count).to eq 1
      expect(row.play_count).to eq 2
    end

    it "異なる楽曲は別々に数えること" do
      alice = create(:customer, name: "Alice")
      event = ended_event
      perform!(event, customer: alice, song_name: "曲X", artist_name: "A")
      perform!(event, customer: alice, song_name: "曲Y", artist_name: "A")

      expect(query(kind: "songs").rows.first.song_count).to eq 2
    end

    it "楽曲数の降順・同数は総演奏回数の降順で並ぶこと" do
      wide = create(:customer, name: "Wide")
      deep = create(:customer, name: "Deep")
      event = ended_event
      perform!(event, customer: wide, song_name: "w1", artist_name: "A")
      perform!(event, customer: wide, song_name: "w2", artist_name: "A")
      perform!(event, customer: deep, song_name: "d1", artist_name: "A")
      perform!(event, customer: deep, song_name: "d1", artist_name: "A") # 同曲2回=楽曲1/演奏2

      rows = query(kind: "songs").rows
      expect(rows.map { |r| r.customer.name }).to eq %w[Wide Deep]
    end
  end

  describe "パート別(kind: parts)" do
    it "指定パートの演奏回数で並び、そのパート実績が無い人は除外すること" do
      guitarist = create(:customer, name: "Guitarist")
      vocalist = create(:customer, name: "Vocalist")
      event = ended_event
      perform!(event, customer: guitarist, song_name: "g1", part: "Guitar")
      perform!(event, customer: guitarist, song_name: "g2", part: "Guitar")
      perform!(event, customer: vocalist, song_name: "v1", part: "Vocal")

      rows = query(kind: "parts", part: "Guitar").rows
      expect(rows.map { |r| r.customer.name }).to eq %w[Guitarist]
      expect(rows.first.part_count).to eq 2
      expect(rows.first.play_count).to eq 2
    end

    it "レガシーなパート名(Gt / ギター)を正規化してGuitarに合算すること" do
      alice = create(:customer, name: "Alice")
      event = ended_event
      perform!(event, customer: alice, song_name: "曲1", part: "Gt")
      perform!(event, customer: alice, song_name: "曲2", part: "ギター")
      perform!(event, customer: alice, song_name: "曲3", part: "Guitar")

      expect(query(kind: "parts", part: "Guitar").rows.first.part_count).to eq 3
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

    it "日本時間の月初0時は当月に含まれ、月末23時台は翌月に含まれないこと" do
      travel_to(Time.zone.local(2026, 9, 15, 12)) do
        alice = create(:customer, name: "Alice")
        perform!(ended_event(start_time: Time.zone.local(2026, 9, 1, 0, 0, 0)), customer: alice, song_name: "月初曲")
        perform!(ended_event(start_time: Time.zone.local(2026, 8, 31, 23, 30, 0)), customer: alice, song_name: "先月末曲")

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

  describe "順位の仕様" do
    it "同数は同順位・次は競技順位(人数分飛ばす)になること" do
      event = ended_event
      counts = { "A" => 3, "B" => 2, "C" => 2, "D" => 1 }
      counts.each do |name, n|
        customer = create(:customer, name: name)
        n.times { |i| perform!(event, customer: customer, song_name: "#{name}#{i}") }
      end

      rows = query.rows
      expect(rows.map(&:rank)).to eq [1, 2, 2, 4]
    end

    it "同率のときは補助集計値の降順・さらに同じならcustomer_id昇順で安定して並ぶこと" do
      event = ended_event
      # 先に作った方が customer_id が小さい。
      first = create(:customer, name: "First")
      second = create(:customer, name: "Second")
      # 総演奏回数・楽曲数ともに同じ(kind: total の主/補助が同値)にする。
      perform!(event, customer: first, song_name: "共通曲", artist_name: "A")
      perform!(event, customer: second, song_name: "共通曲", artist_name: "A")

      rows = query(kind: "total").rows
      expect(rows.map { |r| r.customer.id }).to eq [first.id, second.id]
      expect(rows.map(&:rank)).to eq [1, 1]
    end
  end

  describe "不正なパラメータ" do
    it "想定外の kind / scope / part / community_id でも例外にならず既定値で動くこと" do
      alice = create(:customer, name: "Alice")
      perform!(ended_event, customer: alice)

      q = query(kind: "'; DROP TABLE songs; --", scope: "everywhere", part: "Percussion", community_id: "abc")
      expect { q.rows }.not_to raise_error
      expect(q.kind).to eq "total"
      expect(q.scope).to eq "all"
      expect(q.part).to eq "Vocal"
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
  end
end
