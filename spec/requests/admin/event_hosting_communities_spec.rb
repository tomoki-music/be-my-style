require "rails_helper"

RSpec.describe "イベントの開催コミュニティ(管理画面)", type: :request do
  let(:admin) { FactoryBot.create(:admin) }
  let(:western) { FactoryBot.create(:community, name: "洋楽セッション") }
  let(:japanese) { FactoryBot.create(:community, name: "邦楽セッション") }
  let(:jazz) { FactoryBot.create(:community, name: "ジャズセッション") }
  let(:event) { FactoryBot.create(:event, :event_with_songs, community: western) }

  context "サイト管理者" do
    before { sign_in admin }

    it "編集画面に主催と開催コミュニティの欄を表示する" do
      japanese

      get edit_admin_event_path(event)

      page = Nokogiri::HTML(response.body)
      boxes = page.css("input[type=checkbox][name='event[selected_hosting_community_ids][]']")
      expect(boxes.map { |box| box["value"].to_i }).to include(western.id, japanese.id)
      expect(boxes.select { |box| box["checked"] }.map { |box| box["value"].to_i }).to eq [western.id]
      expect(response.body).to include("主催コミュニティ")
    end

    it "主催を変えずに開催コミュニティを追加でき、詳細・一覧に表示される" do
      patch admin_event_path(event), params: {
        event: { community_id: western.id, selected_hosting_community_ids: ["", western.id, japanese.id] }
      }

      expect(response).to redirect_to(admin_event_path(event))
      expect(event.reload.community_id).to eq western.id
      expect(event.all_hosting_community_ids).to eq [western.id, japanese.id]

      get admin_event_path(event)
      expect(response.body).to include("洋楽セッション / 邦楽セッション")

      get admin_events_path
      expect(response.body).to include("洋楽セッション / 邦楽セッション")
    end

    it "主催のセレクトを変更すると、チェックが無くても新しい主催が開催コミュニティになる" do
      patch admin_event_path(event), params: {
        event: { community_id: jazz.id, selected_hosting_community_ids: [""] }
      }

      expect(response).to redirect_to(admin_event_path(event))
      expect(event.reload.all_hosting_community_ids).to eq [jazz.id]
    end

    it "主催を変えずに全て外すとエラーになり、設定を保持する" do
      patch admin_event_path(event), params: {
        event: { community_id: western.id, selected_hosting_community_ids: [""] }
      }

      expect(response.status).to eq 200
      expect(response.body).to include("開催コミュニティを1つ以上選択してください")
      expect(Event.find(event.id).all_hosting_community_ids).to eq [western.id]
    end

    it "新規作成は従来の単一選択のまま、開催コミュニティの行を作る" do
      get new_admin_event_path
      expect(Nokogiri::HTML(response.body).css("[name='event[selected_hosting_community_ids][]']")).to be_empty

      expect do
        post admin_events_path, params: {
          event: {
            customer_id: FactoryBot.create(:customer).id,
            community_id: western.id,
            event_name: "管理者作成",
            event_start_time: 7.days.from_now,
            event_end_time: 7.days.from_now + 2.hours,
            event_entry_deadline: 6.days.from_now,
            entrance_fee: 1000,
            place: "スタジオ",
            address: "埼玉県さいたま市",
            songs_attributes: { "0" => { song_name: "曲", artist_name: "アーティスト", join_parts_attributes: { "0" => { join_part_name: "ボーカル" } } } }
          }
        }
      end.to change(Event, :count).by(1)

      expect(Event.order(:id).last.event_communities.pluck(:community_id)).to eq [western.id]
    end
  end

  it "管理者でなければ管理画面の更新はできない" do
    sign_in FactoryBot.create(:customer, is_owner: :community_owner)

    patch admin_event_path(event), params: { event: { selected_hosting_community_ids: [western.id, japanese.id] } }

    expect(Event.find(event.id).all_hosting_community_ids).to eq [western.id]
  end
end
