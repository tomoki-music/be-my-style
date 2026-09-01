require 'rails_helper'

RSpec.describe SongRankings::RankingQuery do
  let(:music_domain) { Domain.find_or_create_by!(name: "music") }
  let(:other_domain) { Domain.find_or_create_by!(name: "business") }
  let(:community) { create(:community, domain: music_domain, name: "Aコミュニティ") }
  let(:other_community) { create(:community, domain: music_domain, name: "Bコミュニティ") }

  # 開催日(event_start_time)だけを指定してイベントを作る。:event_with_songs のダミー曲は
  # パートを持たないため集計に影響しない。
  def create_event(start_time, in_community: nil)
    create(
      :event, :event_with_songs,
      community: in_community || community,
      event_start_time: start_time,
      event_end_time: start_time + 2.hours,
      event_entry_deadline: start_time - 1.day
    )
  end

  # event 内に「必要パートがすべて埋まった」= 成立した Song を作る。
  def establish(event, song_name:, artist_name:, parts: %w[Vocal Guitar], withdrawn: false)
    song = create(:song, event: event, song_name: song_name, artist_name: artist_name)
    parts.each do |part_name|
      part = create(:join_part, song: song, join_part_name: part_name)
      create(:join_part_customer, join_part: part, customer: create(:customer, is_deleted: withdrawn))
    end
    song
  end

  # 一部パートが空いている(未成立)Song。
  def half_filled(event, song_name:, artist_name:)
    song = create(:song, event: event, song_name: song_name, artist_name: artist_name)
    filled = create(:join_part, song: song, join_part_name: "Vocal")
    create(:join_part_customer, join_part: filled, customer: create(:customer))
    create(:join_part, song: song, join_part_name: "Guitar") # 参加者なし
    song
  end

  describe "#rows 集計ロジック" do
    it "必要パートがすべて埋まった楽曲を1回として集計すること" do
      establish(create_event(1.day.from_now), song_name: "曲A", artist_name: "X")

      row = described_class.new.rows.first
      expect(row.song_name).to eq "曲A"
      expect(row.established_count).to eq 1
    end

    it "一部の必要パートが空いている楽曲は集計しないこと" do
      half_filled(create_event(1.day.from_now), song_name: "未成立曲", artist_name: "X")

      expect(described_class.new.rows).to be_empty
    end

    it "パートが1件も無い楽曲は集計しないこと" do
      event = create_event(1.day.from_now)
      create(:song, event: event, song_name: "パートなし曲", artist_name: "X")

      expect(described_class.new.rows).to be_empty
    end

    it "退会ユーザーだけのパートは埋まっていないものとして集計しないこと" do
      establish(create_event(1.day.from_now), song_name: "退会のみ曲", artist_name: "X", withdrawn: true)

      expect(described_class.new.rows).to be_empty
    end

    it "開催済みイベントも開催予定イベントも集計すること" do
      establish(create_event(10.days.ago), song_name: "共通曲", artist_name: "X")
      establish(create_event(10.days.from_now), song_name: "共通曲", artist_name: "X")

      row = described_class.new.rows.first
      expect(row.song_name).to eq "共通曲"
      expect(row.established_count).to eq 2
    end

    it "同一SongMasterが別イベントで成立した場合は複数回集計すること" do
      establish(create_event(1.day.from_now), song_name: "リピート曲", artist_name: "X")
      establish(create_event(2.days.from_now), song_name: "リピート曲", artist_name: "X")
      establish(create_event(3.days.from_now), song_name: "リピート曲", artist_name: "X")

      expect(described_class.new.rows.first.established_count).to eq 3
    end

    it "同一イベント内に同じSongMasterのSongが複数あっても1回として数えること" do
      event = create_event(1.day.from_now)
      establish(event, song_name: "重複曲", artist_name: "X")
      establish(event, song_name: "重複曲", artist_name: "X")

      row = described_class.new.rows.first
      expect(row.song_name).to eq "重複曲"
      expect(row.established_count).to eq 1
    end

    it "SongMasterに紐づかないSongは集計対象外とすること" do
      song = establish(create_event(1.day.from_now), song_name: "マスターなし曲", artist_name: "X")
      song.update_columns(song_master_id: nil)

      expect(described_class.new.rows).to be_empty
    end

    it "SongMaster単位で集約すること(曲名・アーティストが一致する別Songは同一行)" do
      establish(create_event(1.day.from_now), song_name: "集約曲", artist_name: "X")
      establish(create_event(2.days.from_now), song_name: "集約曲", artist_name: "X")

      rows = described_class.new.rows
      expect(rows.size).to eq 1
      expect(rows.first.established_count).to eq 2
    end
  end

  describe "#rows 順位の仕様" do
    before do
      3.times { |i| establish(create_event((i + 1).days.from_now), song_name: "A曲", artist_name: "X") }
      2.times { |i| establish(create_event((i + 10).days.from_now), song_name: "B曲", artist_name: "X") }
      2.times { |i| establish(create_event((i + 20).days.from_now), song_name: "C曲", artist_name: "X") }
      1.times { establish(create_event(40.days.from_now), song_name: "D曲", artist_name: "X") }
    end

    it "成立回数の降順で並ぶこと" do
      counts = described_class.new.rows.map(&:established_count)
      expect(counts).to eq [3, 2, 2, 1]
    end

    it "同数は同順位・次は競技順位(人数分飛ばす)になること" do
      ranks = described_class.new.rows.map(&:rank)
      expect(ranks).to eq [1, 2, 2, 4]
    end

    it "同数内は楽曲名の昇順で決定的に並ぶこと" do
      names = described_class.new.rows.map(&:song_name)
      expect(names).to eq %w[A曲 B曲 C曲 D曲]
    end
  end

  describe "#rows 期間別表示(Asia/Tokyo基準)" do
    before do
      establish(create_event(Time.zone.local(2026, 3, 15, 12)), song_name: "3月曲", artist_name: "X")
      establish(create_event(Time.zone.local(2026, 9, 20, 12)), song_name: "9月曲", artist_name: "X")
      establish(create_event(Time.zone.local(2027, 5, 1, 12)), song_name: "翌年曲", artist_name: "X")
    end

    it "月間指定はその年月に開催されるイベントのみ集計すること" do
      rows = described_class.new(period: "monthly", year: "2026", month: "9").rows
      expect(rows.map(&:song_name)).to eq ["9月曲"]
    end

    it "年間指定はその年に開催されるイベントのみ集計すること" do
      rows = described_class.new(period: "yearly", year: "2026").rows
      expect(rows.map(&:song_name)).to match_array %w[3月曲 9月曲]
    end

    it "全期間は期間で絞り込まないこと" do
      rows = described_class.new(period: "all").rows
      expect(rows.map(&:song_name)).to match_array %w[3月曲 9月曲 翌年曲]
    end

    it "日本時間の月初0時は当月に含まれること" do
      establish(create_event(Time.zone.local(2026, 9, 1, 0, 0, 0)), song_name: "月初曲", artist_name: "X")

      rows = described_class.new(period: "monthly", year: "2026", month: "9").rows
      expect(rows.map(&:song_name)).to include("月初曲")
    end

    it "日本時間の月末23時台は翌月に含まれないこと" do
      establish(create_event(Time.zone.local(2026, 8, 31, 23, 30, 0)), song_name: "月末曲", artist_name: "X")

      rows = described_class.new(period: "monthly", year: "2026", month: "9").rows
      expect(rows.map(&:song_name)).not_to include("月末曲")
    end

    it "未来の年月も指定できること" do
      future_year = Time.zone.today.year + 2
      establish(create_event(Time.zone.local(future_year, 6, 1, 12)), song_name: "未来曲", artist_name: "X")

      rows = described_class.new(period: "yearly", year: future_year.to_s).rows
      expect(rows.map(&:song_name)).to eq ["未来曲"]
    end
  end

  describe "#rows コミュニティ・アーティスト絞り込み" do
    before do
      establish(create_event(1.day.from_now, in_community: community), song_name: "A社の曲", artist_name: "あいみょん")
      establish(create_event(2.days.from_now, in_community: other_community), song_name: "B社の曲", artist_name: "米津玄師")
    end

    it "コミュニティ指定でそのコミュニティで成立した楽曲だけに絞れること" do
      rows = described_class.new(community_id: community.id.to_s).rows
      expect(rows.map(&:song_name)).to eq ["A社の曲"]
    end

    it "アーティスト指定でその表示名の楽曲だけに絞れること" do
      rows = described_class.new(artist_name: "米津玄師").rows
      expect(rows.map(&:song_name)).to eq ["B社の曲"]
    end

    it "コミュニティ・アーティスト・期間を組み合わせられること" do
      # 別コミュニティ・同アーティストで別月に成立した曲(条件から外れる)
      establish(create_event(Time.zone.local(2025, 7, 10, 12), in_community: other_community), song_name: "対象外の曲", artist_name: "あいみょん")
      establish(create_event(Time.zone.local(2025, 7, 10, 12), in_community: community), song_name: "A社の7月曲", artist_name: "あいみょん")

      rows = described_class.new(
        period: "monthly", year: "2025", month: "7",
        community_id: community.id.to_s, artist_name: "あいみょん"
      ).rows
      expect(rows.map(&:song_name)).to eq ["A社の7月曲"]
    end
  end

  describe "#rows 不正パラメータ" do
    it "想定外のperiod/year/month/community ID/artistでも例外にならず全期間扱いになること" do
      establish(create_event(1.day.from_now), song_name: "曲A", artist_name: "X")

      query = described_class.new(
        period: "'; DROP TABLE songs; --",
        year: "abc",
        month: "99",
        community_id: "999999",
        artist_name: "存在しないアーティスト' OR 1=1"
      )

      expect { query.rows }.not_to raise_error
      expect(query.period).to eq "all"
      expect(query.month).to be_between(1, 12)
      expect(query.community_id).to be_nil
      expect(query.artist_name).to be_nil
      expect(query.rows.map(&:song_name)).to eq ["曲A"]
    end

    it "該当データ0件でも例外にならず空を返すこと" do
      query = described_class.new(period: "monthly", year: "2000", month: "1")
      expect(query.rows).to be_empty
    end
  end

  describe "#rows 公開範囲" do
    it "musicドメイン以外のコミュニティのイベントは集計しないこと" do
      biz_community = create(:community, domain: other_domain, name: "ビジネス")
      establish(create_event(1.day.from_now, in_community: biz_community), song_name: "ビジネス曲", artist_name: "X")

      expect(described_class.new.rows).to be_empty
    end
  end

  describe "#rows 楽曲詳細リンク用の代表Song" do
    it "成立実績のあるSongのうちID最大のものを決定的に代表として返すこと" do
      event1 = create_event(1.day.from_now)
      event2 = create_event(2.days.from_now)
      establish(event1, song_name: "代表曲", artist_name: "X")
      newer = establish(event2, song_name: "代表曲", artist_name: "X")

      row = described_class.new.rows.first
      expect(row.representative_song_id).to eq newer.id
      expect(row.representative_event_id).to eq event2.id
    end
  end

  describe "#community_options / #artist_options" do
    it "公開対象(musicドメイン)のコミュニティのみを選択肢に含むこと" do
      community
      other_community
      create(:community, domain: other_domain, name: "非対象ビジネス")

      names = described_class.new.community_options.map(&:first)
      expect(names).to include(community.name, other_community.name)
      expect(names).not_to include("非対象ビジネス")
    end

    it "ランキング対象に存在するアーティストのみを選択肢に含むこと" do
      establish(create_event(1.day.from_now), song_name: "曲A", artist_name: "あいみょん")
      half_filled(create_event(2.days.from_now), song_name: "未成立", artist_name: "未成立アーティスト")

      expect(described_class.new.artist_options).to eq ["あいみょん"]
    end
  end

  describe "ページネーション" do
    it "per件ごとにページングされ、順位は全体を通した競技順位になること" do
      3.times { |i| establish(create_event((i + 1).days.from_now), song_name: "人気曲", artist_name: "X") }
      establish(create_event(30.days.from_now), song_name: "マイナー曲", artist_name: "X")

      page2 = described_class.new(per: "1", page: "2").rows
      expect(page2.map(&:song_name)).to eq ["マイナー曲"]
      expect(page2.first.rank).to eq 2
    end
  end
end
