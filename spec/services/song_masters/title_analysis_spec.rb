require "rails_helper"

RSpec.describe SongMasters::TitleAnalysis do
  let(:event) { FactoryBot.create(:event, :event_with_songs) }

  def unlinked(song_name, artist_name = nil)
    song = FactoryBot.create(:song, event: event, song_name: song_name, artist_name: artist_name)
    song.update_column(:song_master_id, nil)
    song
  end

  it "DBを一切変更しないこと(read-only)" do
    unlinked("マリーゴールド", "あいみょん")
    unlinked("あいみょん - マリーゴールド")
    unlinked("【Key+4】あいみょん - マリーゴールド")

    aggregate_failures do
      expect { described_class.call }.not_to change(SongMaster, :count)
      expect { described_class.call }.not_to change { Song.order(:id).pluck(:song_master_id) }
      expect { described_class.call }.not_to change { SongMaster.order(:id).pluck(:updated_at) }
    end
  end

  it "改善前後のSongMaster予定数と統合Song件数を集計すること" do
    unlinked("マリーゴールド", "あいみょん")
    unlinked("マリーゴールド（あいみょん）")
    unlinked("あいみょん - マリーゴールド")
    unlinked("マリーゴールド / あいみょん")
    unlinked("【時間に余裕があれば】マリーゴールド（あいみょん）")

    result = described_class.call

    # 改善前: 「マリーゴールド（あいみょん）」「【…】マリーゴールド（あいみょん）」は
    #   末尾括弧が裏付け(別カラムSong)により分解される。区切り2件は分解されず別キー。
    # 改善後: 5件すべて同一キーへ集約される。
    expect(result.improved_master_count).to be < result.legacy_master_count
    expect(result.consolidated_song_count).to be >= 2
    expect(result.mergeable_examples.map(&:song_name)).to include("あいみょん - マリーゴールド")
  end

  it "先頭注記の種類を集計すること" do
    unlinked("【Key+4】あいみょん - マリーゴールド")
    unlinked("【募集中】オリジナル曲")

    result = described_class.call

    expect(result.leading_annotation_counts).to include("【Key+4】" => 1, "【募集中】" => 1)
  end

  it "裏付けが無い区切り曲は分解されず、誤統合の疑いに数えないこと" do
    unlinked("知らない人 - 知らない曲")

    result = described_class.call

    expect(result.consolidated_song_count).to eq(0)
    expect(result.suspicious_groups).to be_empty
  end
end
