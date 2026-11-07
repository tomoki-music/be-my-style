require "rails_helper"
require Rails.root.join("db/migrate/20261107000000_create_event_communities")

RSpec.describe CreateEventCommunities do
  let(:connection) { ActiveRecord::Base.connection }
  let(:community) { FactoryBot.create(:community) }
  let!(:first_event) { FactoryBot.create(:event, :event_with_songs, community: community) }
  let!(:second_event) { FactoryBot.create(:event, :event_with_songs) }

  def migrate(direction)
    ActiveRecord::Migration.suppress_messages { described_class.new.migrate(direction) }
    EventCommunity.reset_column_information
  end

  it "既存イベントの主催コミュニティを1件ずつ引き継ぎ、events.community_id は変えない" do
    migrate(:down)
    expect(connection.table_exists?(:event_communities)).to eq false

    migrate(:up)

    expect(EventCommunity.order(:event_id).pluck(:event_id, :community_id)).to include(
      [first_event.id, community.id],
      [second_event.id, second_event.community_id]
    )
    expect(EventCommunity.count).to eq Event.count
    expect(first_event.reload.community_id).to eq community.id
  end

  it "途中まで適用された状態から再実行しても重複しない" do
    expect { migrate(:up) }.not_to change(EventCommunity, :count)
  end

  it "主催以外の追加済みの行があっても再実行で消さない" do
    other = FactoryBot.create(:community)
    first_event.update!(selected_cohost_community_ids: [other.id])

    expect { migrate(:up) }.not_to change(EventCommunity, :count)
    expect(first_event.reload.all_hosting_community_ids).to eq [community.id, other.id]
  end

  it "一意制約と外部キーを持つ" do
    expect(connection.index_exists?(:event_communities, [:event_id, :community_id], unique: true)).to eq true
    expect(connection.foreign_key_exists?(:event_communities, :events)).to eq true
    expect(connection.foreign_key_exists?(:event_communities, :communities)).to eq true
  end
end
