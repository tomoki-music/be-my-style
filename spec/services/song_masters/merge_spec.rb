require "rails_helper"

RSpec.describe SongMasters::Merge do
  let(:event) { FactoryBot.create(:event, :event_with_songs) }

  # 正: 「曲名」+「アーティスト欄」で正しく登録されたSongMaster
  let!(:canonical) { SongMasters::Resolver.call(song_name: "ワタリドリ", artist_name: "[Alexandros]") }
  # 統合元: 表記のゆれで正規化キーが割れたSongMaster。
  # decompose では分解されない形にして「統合(=Alias)でしか正へ寄らない」ことを検証する。
  let(:legacy_name) { "ワタリドリ〜Alexandros〜" }
  let!(:duplicate) do
    FactoryBot.create(
      :song_master,
      song_name: legacy_name,
      normalize: false,
      normalized_song_name: SongMasters::Resolver.normalize(legacy_name),
      normalized_artist_name: ""
    )
  end

  def unlinked_song(song_name:, artist_name: nil, song_master:)
    song = FactoryBot.create(:song, event: event, song_name: song_name, artist_name: artist_name)
    song.update_column(:song_master_id, song_master.id)
    song
  end

  describe "dry_run: true" do
    it "DBを一切変更せず、統合予定と実行可否を返すこと" do
      unlinked_song(song_name: legacy_name, song_master: duplicate)
      customer = FactoryBot.create(:customer)
      FactoryBot.create(:customer_song_part, customer: customer, song: nil, song_master: duplicate, part_name: "Guitar")

      result = nil
      aggregate_failures do
        expect { result = described_class.call(canonical_id: canonical.id, duplicate_id: duplicate.id, dry_run: true) }
          .not_to change { [SongMaster.count, Song.count, CustomerSongPart.count, SongMasterAlias.count] }
        expect(SongMaster.exists?(duplicate.id)).to be(true)
      end

      expect(result.dry_run).to be(true)
      expect(result.performed).to be_falsey
      expect(result.movable_song_count).to eq(1)
      expect(result.movable_customer_song_part_count).to eq(1)
      expect(result.conflicting_customer_song_part_count).to eq(0)
      expect(result.planned_alias.song_master_id).to eq(canonical.id)
      expect(result.planned_alias.normalized_song_name).to eq(SongMasters::Resolver.normalize(legacy_name))
      expect(result.deletable_song_master_id).to eq(duplicate.id)
      expect(result.unknown_references).to be_empty
      expect(result).to be_executable
      expect(result.aborted_reason).to be_nil
    end

    it "UNIQUE衝突するCustomerSongPart数を数えるが、DBは変更しないこと" do
      customer = FactoryBot.create(:customer)
      FactoryBot.create(:customer_song_part, customer: customer, song: nil, song_master: canonical, part_name: "Vocal")
      FactoryBot.create(:customer_song_part, customer: customer, song: nil, song_master: duplicate, part_name: "Vocal")

      result = described_class.call(canonical_id: canonical.id, duplicate_id: duplicate.id, dry_run: true)

      expect(result.conflicting_customer_song_part_count).to eq(1)
      expect(result).to be_executable
      expect(CustomerSongPart.where(song_master_id: duplicate.id).count).to eq(1)
    end
  end

  describe "dry_run: false" do
    it "Song・CustomerSongPartを正へ付け替え、Aliasを作成し、統合元を削除すること" do
      song = unlinked_song(song_name: legacy_name, song_master: duplicate)
      customer = FactoryBot.create(:customer)
      csp = FactoryBot.create(:customer_song_part, customer: customer, song: nil, song_master: duplicate, part_name: "Guitar")

      result = described_class.call(canonical_id: canonical.id, duplicate_id: duplicate.id, dry_run: false)

      aggregate_failures do
        expect(result.performed).to be(true)
        expect(song.reload.song_master_id).to eq(canonical.id)
        expect(csp.reload.song_master_id).to eq(canonical.id)
        expect(SongMaster.exists?(duplicate.id)).to be(false)
        expect(SongMaster.exists?(canonical.id)).to be(true)

        alias_record = SongMasterAlias.find_by(normalized_song_name: SongMasters::Resolver.normalize(legacy_name))
        expect(alias_record.song_master_id).to eq(canonical.id)
        expect(alias_record.normalized_artist_name).to eq("")
      end
    end

    it "UNIQUE衝突するCustomerSongPartは統合元側を削除し、正側を残すこと" do
      customer = FactoryBot.create(:customer)
      keep = FactoryBot.create(:customer_song_part, customer: customer, song: nil, song_master: canonical, part_name: "Vocal")
      drop = FactoryBot.create(:customer_song_part, customer: customer, song: nil, song_master: duplicate, part_name: "Vocal")
      # 衝突しないパートはそのまま移動する
      move = FactoryBot.create(:customer_song_part, customer: customer, song: nil, song_master: duplicate, part_name: "Bass")

      result = described_class.call(canonical_id: canonical.id, duplicate_id: duplicate.id, dry_run: false)

      aggregate_failures do
        expect(result.customer_song_parts_deduped).to eq(1)
        expect(CustomerSongPart.exists?(keep.id)).to be(true)
        expect(CustomerSongPart.exists?(drop.id)).to be(false)
        expect(move.reload.song_master_id).to eq(canonical.id)
        expect(
          CustomerSongPart.where(customer_id: customer.id, song_master_id: canonical.id).pluck(:part_name)
        ).to match_array(%w[Vocal Bass])
      end
    end

    it "衝突するCustomerSongPartのsong_idが両方非nilで食い違う場合は中止し、DBを変更しないこと" do
      customer = FactoryBot.create(:customer)
      song_a = FactoryBot.create(:song, event: event, song_name: "A")
      song_b = FactoryBot.create(:song, event: event, song_name: "B")
      FactoryBot.create(:customer_song_part, customer: customer, song: song_a, song_master: canonical, part_name: "Vocal")
      FactoryBot.create(:customer_song_part, customer: customer, song: song_b, song_master: duplicate, part_name: "Vocal")

      result = nil
      expect { result = described_class.call(canonical_id: canonical.id, duplicate_id: duplicate.id, dry_run: false) }
        .not_to change { [SongMaster.count, CustomerSongPart.count, SongMasterAlias.count] }

      expect(result.performed).to be_falsey
      expect(result).not_to be_executable
      expect(result.aborted_reason).to match(/内容が異なる/)
      expect(SongMaster.exists?(duplicate.id)).to be(true)
    end

    it "統合後、旧表記のSongを保存し直しても分裂SongMasterが再作成されないこと" do
      described_class.call(canonical_id: canonical.id, duplicate_id: duplicate.id, dry_run: false)

      expect {
        resolved = SongMasters::Resolver.call(song_name: legacy_name, artist_name: nil)
        expect(resolved.id).to eq(canonical.id)
      }.not_to change(SongMaster, :count)
    end

    it "resolve_existing も Alias 経由で正SongMasterへ解決すること" do
      described_class.call(canonical_id: canonical.id, duplicate_id: duplicate.id, dry_run: false)

      resolved = SongMasters::Resolver.resolve_existing(song_name: legacy_name, artist_name: nil)
      expect(resolved&.id).to eq(canonical.id)
    end

    it "統合を再実行しても冪等(統合元が無ければ already_merged としてエラーにしないこと)" do
      described_class.call(canonical_id: canonical.id, duplicate_id: duplicate.id, dry_run: false)

      result = nil
      expect { result = described_class.call(canonical_id: canonical.id, duplicate_id: duplicate.id, dry_run: false) }
        .not_to change { [SongMaster.count, SongMasterAlias.count] }
      expect(result.already_merged).to be(true)
      expect(result).not_to be_executable
    end

    it "同じ統合を再度DRY RUNしても already_merged を返すこと" do
      described_class.call(canonical_id: canonical.id, duplicate_id: duplicate.id, dry_run: false)

      result = described_class.call(canonical_id: canonical.id, duplicate_id: duplicate.id, dry_run: true)
      expect(result.already_merged).to be(true)
    end
  end

  describe "ガード" do
    it "正と統合元が同じIDなら実行しないこと" do
      result = described_class.call(canonical_id: canonical.id, duplicate_id: canonical.id, dry_run: false)
      expect(result).not_to be_executable
      expect(result.aborted_reason).to match(/同じID/)
    end

    it "正SongMasterが存在しなければ実行しないこと" do
      result = described_class.call(canonical_id: 0, duplicate_id: duplicate.id, dry_run: true)
      expect(result).not_to be_executable
      expect(result.aborted_reason).to match(/正SongMaster/)
    end

    it "song_masters を参照する未知の外部キーがあれば統合を中止すること" do
      allow_any_instance_of(described_class)
        .to receive(:referencing_columns)
        .and_return(%w[songs.song_master_id customer_song_parts.song_master_id song_master_aliases.song_master_id mystery.song_master_id])

      result = nil
      expect { result = described_class.call(canonical_id: canonical.id, duplicate_id: duplicate.id, dry_run: false) }
        .not_to change(SongMaster, :count)
      expect(result).not_to be_executable
      expect(result.aborted_reason).to match(/未知の外部キー/)
      expect(result.unknown_references).to eq(%w[mystery.song_master_id])
    end
  end
end
