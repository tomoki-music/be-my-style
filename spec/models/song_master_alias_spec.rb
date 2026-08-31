require "rails_helper"

RSpec.describe SongMasterAlias, type: :model do
  it "song_master と normalized_song_name があれば有効であること" do
    canonical = FactoryBot.create(:song_master)
    record = described_class.new(
      song_master: canonical,
      normalized_song_name: SongMasters::Resolver.normalize("旧曲名（旧アーティスト）"),
      normalized_artist_name: ""
    )

    expect(record).to be_valid
  end

  it "normalized_song_name が空なら無効であること" do
    record = FactoryBot.build(:song_master_alias, normalized_song_name: "")
    expect(record).not_to be_valid
  end

  it "同じ正規化キーの組み合わせは重複登録できないこと(DB UNIQUE制約と対応)" do
    key = SongMasters::Resolver.normalize("重複キー曲")
    FactoryBot.create(:song_master_alias, normalized_song_name: key, normalized_artist_name: "")

    dup = FactoryBot.build(:song_master_alias, normalized_song_name: key, normalized_artist_name: "")
    expect(dup).not_to be_valid
  end

  it "曲名が同じでもアーティスト名が異なれば別エイリアスとして登録できること" do
    key = SongMasters::Resolver.normalize("同名キー曲")
    FactoryBot.create(:song_master_alias, normalized_song_name: key, normalized_artist_name: "a")

    other = FactoryBot.build(:song_master_alias, normalized_song_name: key, normalized_artist_name: "b")
    expect(other).to be_valid
  end

  it "正SongMasterが削除されると一緒に削除されること(dependent: :destroy)" do
    canonical = FactoryBot.create(:song_master)
    FactoryBot.create(:song_master_alias, song_master: canonical)

    expect { canonical.destroy }.to change(described_class, :count).by(-1)
  end
end
