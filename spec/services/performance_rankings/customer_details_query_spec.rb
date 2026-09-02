require 'rails_helper'

RSpec.describe PerformanceRankings::CustomerDetailsQuery do
  include ActiveSupport::Testing::TimeHelpers

  let(:music_domain) { Domain.find_or_create_by!(name: "music") }
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:community) { create(:community, domain: music_domain, name: "Aコミュニティ") }
  let(:other_community) { create(:community, domain: music_domain, name: "Bコミュニティ") }

  def ended_event(start_time: 20.days.ago, in_community: nil, name: nil)
    create(
      :event, :event_with_songs,
      community: in_community || community,
      event_name: name || "イベント#{start_time.to_i}",
      event_start_time: start_time,
      event_end_time: start_time + 2.hours,
      event_entry_deadline: start_time - 1.day
    )
  end

  def perform!(event, customer:, song_name: "曲", artist_name: "A", part: "Vocal", song: nil)
    song ||= create(:song, event: event, song_name: song_name, artist_name: artist_name)
    join_part = create(:join_part, song: song, join_part_name: part)
    create(:join_part_customer, join_part: join_part, customer: customer)
    song
  end

  def call(customer, **opts)
    described_class.new(customer_ids: [customer.id], **opts).call[customer.id]
  end

  describe "参加イベント" do
    it "そのユーザーが演奏したイベントを開催日の降順で、演奏数つきで返すこと" do
      alice = create(:customer, name: "Alice")
      old_event = ended_event(start_time: 40.days.ago, name: "古いイベント")
      new_event = ended_event(start_time: 5.days.ago, name: "新しいイベント")
      perform!(old_event, customer: alice, song_name: "曲A", part: "Vocal")
      perform!(new_event, customer: alice, song_name: "曲B", part: "Vocal")
      perform!(new_event, customer: alice, song_name: "曲C", part: "Guitar")

      detail = call(alice)
      expect(detail.events.map(&:name)).to eq ["新しいイベント", "古いイベント"]
      expect(detail.events.map(&:play_count)).to eq [2, 1]
      expect(detail.events.first.event_id).to eq new_event.id
      expect(detail.events.first.held_on).to eq new_event.event_start_time.to_date
    end
  end

  describe "演奏した楽曲" do
    it "同じSongMasterの曲をまとめ、演奏回数の降順・担当パート内訳つきで返すこと" do
      alice = create(:customer, name: "Alice")
      e1 = ended_event(start_time: 30.days.ago)
      e2 = ended_event(start_time: 10.days.ago)

      # マリーゴールド: Vo 2回 / Gt 1回 = 3演奏
      mg1 = perform!(e1, customer: alice, song_name: "マリーゴールド", artist_name: "あいみょん", part: "Vocal")
      perform!(e1, customer: alice, song: mg1, part: "Guitar")
      perform!(e2, customer: alice, song_name: "マリーゴールド", artist_name: "あいみょん", part: "Vocal")
      # 丸の内サディスティック: Gt 2回
      perform!(e1, customer: alice, song_name: "丸の内サディスティック", artist_name: "椎名林檎", part: "Guitar")
      perform!(e2, customer: alice, song_name: "丸の内サディスティック", artist_name: "椎名林檎", part: "Guitar")

      detail = call(alice)
      expect(detail.songs.map(&:name)).to eq ["マリーゴールド", "丸の内サディスティック"]
      expect(detail.songs.map(&:play_count)).to eq [3, 2]
      expect(detail.songs.first.part_counts).to eq [["Vocal", 2], ["Guitar", 1]]
      expect(detail.songs.second.part_counts).to eq [["Guitar", 2]]
    end

    it "SongMaster未解決の曲は含めないこと" do
      alice = create(:customer, name: "Alice")
      song = perform!(ended_event, customer: alice, song_name: "未解決曲")
      song.update_columns(song_master_id: nil)

      expect(call(alice)).to be_nil
    end
  end

  describe "担当パート" do
    it "正規化済みパート名で、回数の降順・0回除外で返すこと" do
      alice = create(:customer, name: "Alice")
      event = ended_event
      perform!(event, customer: alice, song_name: "曲1", part: "Vocal")
      perform!(event, customer: alice, song_name: "曲2", part: "Vo")     # 正規化で Vocal
      perform!(event, customer: alice, song_name: "曲3", part: "ギター")  # 正規化で Guitar

      detail = call(alice)
      expect(detail.parts).to eq [["Vocal", 2], ["Guitar", 1]]
    end

    it "正規化できないパートは対象外であること" do
      alice = create(:customer, name: "Alice")
      perform!(ended_event, customer: alice, song_name: "曲1", part: "Vocal")
      perform!(ended_event, customer: alice, song_name: "曲2", part: "Chorus")

      detail = call(alice)
      expect(detail.parts).to eq [["Vocal", 1]]
    end
  end

  describe "範囲・期間の適用" do
    it "対象期間外の演奏は詳細に混ざらないこと" do
      alice = create(:customer, name: "Alice")
      perform!(ended_event(start_time: Time.zone.local(2026, 3, 10, 12), name: "対象"), customer: alice, song_name: "対象曲")
      perform!(ended_event(start_time: Time.zone.local(2025, 1, 10, 12), name: "対象外"), customer: alice, song_name: "対象外曲")

      detail = call(alice, period: PerformanceRankings::Period.new(preset: "custom", start_on: "2026-03-01", end_on: "2026-03-31"))
      expect(detail.events.map(&:name)).to eq ["対象"]
      expect(detail.songs.map(&:name)).to eq ["対象曲"]
    end

    it "別コミュニティの演奏は詳細に混ざらないこと" do
      alice = create(:customer, name: "Alice")
      perform!(ended_event(in_community: community, name: "こっち"), customer: alice, song_name: "こっち曲")
      perform!(ended_event(in_community: other_community, name: "あっち"), customer: alice, song_name: "あっち曲")

      detail = call(alice, scope: "community", community_id: community.id)
      expect(detail.events.map(&:name)).to eq ["こっち"]
      expect(detail.songs.map(&:name)).to eq ["こっち曲"]
    end

    it "終了済みイベントの演奏だけを含めること" do
      alice = create(:customer, name: "Alice")
      upcoming = create(
        :event, :event_with_songs, community: community,
        event_start_time: 10.days.from_now, event_end_time: 10.days.from_now + 2.hours,
        event_entry_deadline: 5.days.from_now
      )
      perform!(upcoming, customer: alice, song_name: "開催前曲")

      expect(call(alice)).to be_nil
    end
  end

  describe "取得範囲" do
    it "指定した customer_id 群だけの詳細を返すこと" do
      alice = create(:customer, name: "Alice")
      bob = create(:customer, name: "Bob")
      event = ended_event
      perform!(event, customer: alice, song_name: "A曲")
      perform!(event, customer: bob, song_name: "B曲")

      result = described_class.new(customer_ids: [alice.id]).call
      expect(result.keys).to eq [alice.id]
    end

    it "customer_id が空なら空を返すこと" do
      expect(described_class.new(customer_ids: []).call).to eq({})
    end

    it "退会ユーザーは含めないこと" do
      withdrawn = create(:customer, name: "Withdrawn", is_deleted: true)
      perform!(ended_event, customer: withdrawn, song_name: "退会曲")

      expect(call(withdrawn)).to be_nil
    end
  end

  describe "クエリ数" do
    it "対象ユーザー数を増やしてもクエリ数が比例しないこと" do
      event = ended_event
      few = create_list(:customer, 2)
      few.each_with_index { |c, i| perform!(event, customer: c, song_name: "few#{i}") }

      baseline = count_queries { described_class.new(customer_ids: few.map(&:id)).call }

      many = create_list(:customer, 8)
      many.each_with_index { |c, i| perform!(event, customer: c, song_name: "many#{i}") }

      grown = count_queries { described_class.new(customer_ids: (few + many).map(&:id)).call }

      expect(grown).to be <= baseline + 1
    end
  end

  def count_queries(&block)
    count = 0
    counter = ->(_name, _start, _finish, _id, payload) do
      count += 1 unless payload[:name].to_s =~ /SCHEMA|TRANSACTION/ || payload[:sql] =~ /^\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i
    end
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end
end
