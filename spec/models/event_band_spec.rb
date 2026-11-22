require "rails_helper"

RSpec.describe EventBand, type: :model do
  let(:community) { FactoryBot.create(:community) }
  let(:event) { FactoryBot.create(:event, :event_with_songs, community: community) }
  let(:song) { FactoryBot.create(:song, event: event) }
  let(:member) { FactoryBot.create(:customer) }

  before { CommunityCustomer.create!(customer: member, community: community) }

  it "会員も表示名も空のパートは担当なしにし、会員を選んだパートは表示名を持たない" do
    band = event.event_bands.build(name: "バンド")
    band.assign_part_members(
      "Vocal" => { "customer_id" => member.id.to_s, "display_name" => "無視される" },
      "Guitar" => { "customer_id" => "", "display_name" => " ゲスト " },
      "Bass" => { "customer_id" => "", "display_name" => "" }
    )
    band.save!

    expect(band.reload.ordered_members.map { |m| [m.part_name, m.customer_id, m.display_name] })
      .to eq [["Vocal", member.id, nil], ["Guitar", nil, "ゲスト"]]
  end

  it "同じバンドの同じパートに担当者は1人まで" do
    band = event.event_bands.create!(name: "バンド")
    band.members.create!(part_name: "Vocal", display_name: "A")
    expect(band.members.build(part_name: "Vocal", display_name: "B")).not_to be_valid
  end

  it "パート名は既存の募集パート名だけを使える" do
    band = event.event_bands.build(name: "バンド")
    band.members.build(part_name: "Trumpet", display_name: "A")
    expect(band).not_to be_valid
  end

  it "バンド出演曲は募集パートを持たず成立扱いになり、応援は数に入らない" do
    FactoryBot.create(:join_part, song: song, join_part_name: "Vocal")
    SongCheer.create!(song: song, customer: member)
    expect(song.reload).to be_recruiting

    event.event_bands.create!(name: "バンド", selected_song_ids: [song.id])
    song.reload
    expect(song).to be_band_performance
    expect(song.recruiting_join_parts).to be_empty
    expect(song).to be_established
  end
end
