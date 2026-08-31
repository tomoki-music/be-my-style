require "rails_helper"

RSpec.describe SongMasters::MergeBatch do
  describe ".resolve_apply_mode" do
    it "環境変数なしは DRY RUN(false)であること" do
      expect(described_class.resolve_apply_mode({})).to be(false)
    end

    it "DRY_RUN=true は DRY RUN であること" do
      expect(described_class.resolve_apply_mode({ "DRY_RUN" => "true" })).to be(false)
    end

    it "APPLY=false 単体は DRY RUN であること" do
      expect(described_class.resolve_apply_mode({ "APPLY" => "false" })).to be(false)
    end

    it "APPLY=true と CONFIRM=MERGE_SONG_MASTERS の両方で本適用(true)になること" do
      expect(
        described_class.resolve_apply_mode({ "APPLY" => "true", "CONFIRM" => "MERGE_SONG_MASTERS" })
      ).to be(true)
    end

    it "APPLY=true だけはエラーになること" do
      expect { described_class.resolve_apply_mode({ "APPLY" => "true" }) }
        .to raise_error(described_class::ConfigError, /CONFIRM/)
    end

    it "CONFIRM だけはエラーになること" do
      expect { described_class.resolve_apply_mode({ "CONFIRM" => "MERGE_SONG_MASTERS" }) }
        .to raise_error(described_class::ConfigError, /APPLY=true/)
    end

    it "APPLY=true + DRY_RUN=true の矛盾はエラーになること" do
      expect {
        described_class.resolve_apply_mode(
          { "APPLY" => "true", "CONFIRM" => "MERGE_SONG_MASTERS", "DRY_RUN" => "true" }
        )
      }.to raise_error(described_class::ConfigError, /同時に指定できません/)
    end

    it "APPLY=false + CONFIRM=MERGE_SONG_MASTERS の矛盾はエラーになること" do
      expect {
        described_class.resolve_apply_mode({ "APPLY" => "false", "CONFIRM" => "MERGE_SONG_MASTERS" })
      }.to raise_error(described_class::ConfigError)
    end

    it "DRY_RUN=false 単体はエラーになること(曖昧なので本適用にしない)" do
      expect { described_class.resolve_apply_mode({ "DRY_RUN" => "false" }) }
        .to raise_error(described_class::ConfigError, /DRY_RUN=false/)
    end

    it "CONFIRM の値が不正ならエラーになること" do
      expect {
        described_class.resolve_apply_mode({ "APPLY" => "true", "CONFIRM" => "yes" })
      }.to raise_error(described_class::ConfigError, /CONFIRM/)
    end
  end

  describe ".parse_pairs" do
    it "keep:merge のカンマ区切りを Pair に変換すること" do
      pairs = described_class.parse_pairs(" 43:398 , 93:102 ")
      expect(pairs.map { |p| [p.keep_id, p.merge_id] }).to eq([[43, 398], [93, 102]])
    end

    it "未指定はエラーにすること" do
      expect { described_class.parse_pairs(nil) }.to raise_error(described_class::ConfigError)
      expect { described_class.parse_pairs("   ") }.to raise_error(described_class::ConfigError)
    end

    it "数値以外はエラーにすること" do
      expect { described_class.parse_pairs("43:abc") }.to raise_error(described_class::ConfigError)
    end

    it "不正な形式(コロン無し・多重コロン)はエラーにすること" do
      expect { described_class.parse_pairs("43-398") }.to raise_error(described_class::ConfigError)
      expect { described_class.parse_pairs("43:398:1") }.to raise_error(described_class::ConfigError)
    end

    it "余分な区切り文字・空要素はエラーにすること" do
      expect { described_class.parse_pairs("43:398,") }.to raise_error(described_class::ConfigError)
      expect { described_class.parse_pairs("43:398,,93:102") }.to raise_error(described_class::ConfigError)
    end

    it "同一IDのペアはエラーにすること" do
      expect { described_class.parse_pairs("43:43") }.to raise_error(described_class::ConfigError)
    end

    it "0以下のIDはエラーにすること" do
      expect { described_class.parse_pairs("0:398") }.to raise_error(described_class::ConfigError)
    end

    it "ペア重複はエラーにすること" do
      expect { described_class.parse_pairs("43:398,43:398") }.to raise_error(described_class::ConfigError, /重複/)
    end

    it "merge ID の重複はエラーにすること" do
      expect { described_class.parse_pairs("43:398,50:398") }.to raise_error(described_class::ConfigError, /merge ID/)
    end

    it "keep ID の重複はエラーにすること" do
      expect { described_class.parse_pairs("43:398,43:399") }.to raise_error(described_class::ConfigError, /keep ID/)
    end

    it "keep と merge の交差(連鎖・循環)はエラーにすること" do
      expect { described_class.parse_pairs("43:398,398:500") }.to raise_error(described_class::ConfigError, /連鎖・循環/)
      expect { described_class.parse_pairs("43:398,500:43") }.to raise_error(described_class::ConfigError, /連鎖・循環/)
    end
  end

  describe "統合の実行" do
    let(:event) { FactoryBot.create(:event, :event_with_songs) }

    def split_master(song_name)
      FactoryBot.create(
        :song_master,
        song_name: song_name,
        normalize: false,
        normalized_song_name: SongMasters::Resolver.normalize(song_name),
        normalized_artist_name: ""
      )
    end

    def unlinked_song(song_name:, song_master:)
      song = FactoryBot.create(:song, event: event, song_name: song_name)
      song.update_column(:song_master_id, song_master.id)
      song
    end

    let!(:keep_a) { SongMasters::Resolver.call(song_name: "曲A", artist_name: "P1") }
    let!(:keep_b) { SongMasters::Resolver.call(song_name: "曲B", artist_name: "P2") }
    let(:legacy_a) { "曲A〜P1〜" }
    let(:legacy_b) { "曲B〜P2〜" }
    let!(:merge_a) { split_master(legacy_a) }
    let!(:merge_b) { split_master(legacy_b) }

    let(:pairs) do
      [
        described_class::Pair.new(keep_id: keep_a.id, merge_id: merge_a.id),
        described_class::Pair.new(keep_id: keep_b.id, merge_id: merge_b.id)
      ]
    end

    describe "DRY RUN" do
      it "DBを一切変更せず、全ペア実行可能なら ready: true を返すこと" do
        unlinked_song(song_name: legacy_a, song_master: merge_a)
        unlinked_song(song_name: legacy_b, song_master: merge_b)

        result = nil
        expect { result = described_class.new(pairs: pairs, apply: false).call }
          .not_to change { [SongMaster.count, Song.count, SongMasterAlias.count] }

        expect(result.ready).to be(true)
        expect(result.applied).to be(false)
        expect(SongMaster.exists?(merge_a.id)).to be(true)
      end

      it "1組でも実行不能なら全体を ready: false にすること" do
        result = described_class.new(
          pairs: pairs + [described_class::Pair.new(keep_id: keep_a.id + 9_999, merge_id: merge_a.id + 9_999)],
          apply: false
        ).call

        expect(result.ready).to be(false)
      end
    end

    describe "APPLY(本適用)" do
      it "全ペアを1トランザクションで統合すること" do
        song_a = unlinked_song(song_name: legacy_a, song_master: merge_a)
        song_b = unlinked_song(song_name: legacy_b, song_master: merge_b)

        result = described_class.new(pairs: pairs, apply: true).call

        aggregate_failures do
          expect(result.applied).to be(true)
          expect(SongMaster.exists?(merge_a.id)).to be(false)
          expect(SongMaster.exists?(merge_b.id)).to be(false)
          expect(song_a.reload.song_master_id).to eq(keep_a.id)
          expect(song_b.reload.song_master_id).to eq(keep_b.id)
        end
      end

      it "2組目以降が失敗したら1組目を含めて全ロールバックすること" do
        unlinked_song(song_name: legacy_a, song_master: merge_a)
        broken = [
          described_class::Pair.new(keep_id: keep_a.id, merge_id: merge_a.id),
          described_class::Pair.new(keep_id: keep_b.id, merge_id: -1) # 2組目は形式上通るが preflight で不能
        ]
        # Pair は parse_pairs を経由しない直接生成なので、merge が存在しないケースを作る
        broken[1] = described_class::Pair.new(keep_id: keep_b.id, merge_id: 9_999_999)

        result = nil
        expect { result = described_class.new(pairs: broken, apply: true).call }
          .not_to change { [SongMaster.count, SongMasterAlias.count, Song.where(song_master_id: merge_a.id).count] }

        expect(result.applied).to be(false)
        expect(result.aborted_reason).to be_present
        expect(SongMaster.exists?(merge_a.id)).to be(true)
      end

      it "merge側が存在しない場合はDB変更なしで全体を中止すること" do
        merge_a.destroy

        result = nil
        expect { result = described_class.new(pairs: pairs, apply: true).call }
          .not_to change { [SongMaster.count, SongMasterAlias.count] }

        expect(result.applied).to be(false)
        expect(result.aborted_reason).to match(/存在しません/)
        expect(SongMaster.exists?(merge_b.id)).to be(true)
      end
    end
  end
end
