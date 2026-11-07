require "rails_helper"

RSpec.describe "イベントの開催コミュニティ(管理画面)", type: :request do
  let(:admin) { FactoryBot.create(:admin) }
  let(:western) { FactoryBot.create(:community, name: "洋楽セッション") }
  let(:japanese) { FactoryBot.create(:community, name: "邦楽セッション") }
  let(:jazz) { FactoryBot.create(:community, name: "ジャズセッション") }
  let(:event) { FactoryBot.create(:event, :event_with_songs, community: western) }

  context "サイト管理者" do
    before { sign_in admin }

    it "編集画面に主催セレクト・固定表示・共催先・旧主催を残す指定を表示する" do
      japanese

      get edit_admin_event_path(event)

      page = Nokogiri::HTML(response.body)
      boxes = page.css("input[type=checkbox][name='event[selected_cohost_community_ids][]']")
      expect(boxes.map { |box| box["value"].to_i }).to include(japanese.id)
      expect(boxes.map { |box| box["value"].to_i }).not_to include(western.id)
      expect(page.css(".event-hosting-communities__primary").text).to include("洋楽セッション")
      expect(page.css("select[name='event[community_id]'] option[selected]").first["value"].to_i).to eq western.id
      keep = page.css("input[type=checkbox][name='event[keep_previous_primary_as_cohost]']").first
      expect(keep["checked"]).to be_present
      expect(response.body).to include("現在の主催「洋楽セッション」を共催先として残す")
    end

    it "主催を変えずに共催先を追加でき、詳細・一覧に表示される" do
      patch admin_event_path(event), params: {
        event: { community_id: western.id, keep_previous_primary_as_cohost: "1", selected_cohost_community_ids: ["", japanese.id] }
      }

      expect(response).to redirect_to(admin_event_path(event))
      expect(flash[:notice]).to eq "イベントを更新しました。"
      expect(event.reload.community_id).to eq western.id
      expect(event.all_hosting_community_ids).to eq [western.id, japanese.id]

      get admin_event_path(event)
      page = Nokogiri::HTML(response.body)
      expect(page.text).to include("主催コミュニティ", "共催先", "邦楽セッション")

      get admin_events_path
      expect(response.body).to include("洋楽セッション / 邦楽セッション")
    end

    it "主催を変更して旧主催を残すと、新しい主催が含まれ、結果を画面で案内する" do
      patch admin_event_path(event), params: {
        event: { community_id: jazz.id, keep_previous_primary_as_cohost: "1", selected_cohost_community_ids: [""] }
      }

      expect(response).to redirect_to(admin_event_path(event))
      fresh = Event.find(event.id)
      expect(fresh.community_id).to eq jazz.id
      expect(fresh.event_communities.pluck(:community_id)).to contain_exactly(jazz.id, western.id)
      expect(flash[:notice]).to include("主催を「洋楽セッション」から「ジャズセッション」に変更し、「洋楽セッション」は共催先に残しました。")
    end

    it "主催を変更して旧主催を残さないと、共催先から外れたことを案内する" do
      patch admin_event_path(event), params: {
        event: { community_id: jazz.id, keep_previous_primary_as_cohost: "0", selected_cohost_community_ids: ["", japanese.id] }
      }

      fresh = Event.find(event.id)
      expect(fresh.event_communities.pluck(:community_id)).to contain_exactly(jazz.id, japanese.id)
      expect(flash[:notice]).to include("「洋楽セッション」は共催先から外しました。")
    end

    it "主催を変更すると編集権限が新しい主催のオーナーへ移る" do
      western.update!(owner_id: event.customer_id)
      new_owner = FactoryBot.create(:customer, is_owner: :community_owner)
      CommunityOwner.create!(customer: new_owner, community: jazz)
      jazz.update!(owner_id: new_owner.id)
      expect(new_owner.can_edit_event?(event)).to eq false

      patch admin_event_path(event), params: { event: { community_id: jazz.id, keep_previous_primary_as_cohost: "1" } }

      expect(new_owner.can_edit_event?(Event.find(event.id))).to eq true
    end

    it "セレクトを変えずに主催を外す直接リクエストでは主催は変わらない" do
      patch admin_event_path(event), params: {
        event: { community_id: western.id, selected_cohost_community_ids: [japanese.id] }
      }

      fresh = Event.find(event.id)
      expect(fresh.community_id).to eq western.id
      expect(fresh.event_communities.pluck(:community_id)).to contain_exactly(western.id, japanese.id)
    end

    it "存在しない共催先を指定するとエラーで再表示し、主催も変更しない" do
      patch admin_event_path(event), params: {
        event: { community_id: jazz.id, selected_cohost_community_ids: [999_999_999] }
      }

      expect(response.status).to eq 200
      expect(response.body).to include("存在しないコミュニティ")
      expect(response.body).to include("現在の主催「洋楽セッション」を共催先として残す")
      expect(Event.find(event.id).community_id).to eq western.id
    end

    it "共催イベントを主催するコミュニティは管理画面でも削除できず、案内ページに管理画面のリンクを出す" do
      event.update!(selected_cohost_community_ids: [japanese.id])
      sign_in FactoryBot.create(:customer, is_owner: :admin)

      expect { delete admin_community_path(western) }.not_to change(Community, :count)

      expect(response).to redirect_to(destroy_blocked_admin_community_path(western))
      follow_redirect!
      expect(response.status).to eq 200
      expect(response.body).to include("先に管理画面で主催を変更します", event.event_name, edit_admin_event_path(event))
      expect(response.body).not_to include("サイト管理者へ依頼")
    end

    it "共催先の指定を省いて別ドメインへ主催だけを変える直接 PATCH は、主催も共催先も変更しない" do
      event.update!(selected_cohost_community_ids: [japanese.id])
      business = FactoryBot.create(:community, domain: Domain.find_or_create_by!(name: "business"))

      patch admin_event_path(event), params: { event: { community_id: business.id } }

      expect(response.status).to eq 200
      expect(response.body).to include("異なるサービスのコミュニティは共催先にできません")
      fresh = Event.find(event.id)
      expect(fresh.community_id).to eq western.id
      expect(fresh.event_communities.pluck(:community_id)).to contain_exactly(western.id, japanese.id)
    end

    context "リクエスト者" do
      let(:song) { event.songs.first }

      def member_of(community)
        FactoryBot.create(:customer).tap { |customer| CommunityCustomer.create!(customer: customer, community: community) }
      end

      it "旧主催を残さない主催変更でも、登録済みのリクエスト者を保持してフォームに表示する" do
        requester = member_of(western)
        song.update!(requested_by_customer_id: requester.id)

        patch admin_event_path(event), params: {
          event: { community_id: jazz.id, keep_previous_primary_as_cohost: "0", songs_attributes: { "0" => { id: song.id, requested_by_customer_id: requester.id } } }
        }

        expect(response).to redirect_to(admin_event_path(event))
        expect(Song.find(song.id).requested_by_customer_id).to eq requester.id
        expect(Event.find(event.id).all_hosting_community_ids).to eq [jazz.id]

        get edit_admin_event_path(event)
        selected = Nokogiri::HTML(response.body).css("select[name*='requested_by_customer_id'] option[selected]")
        expect(selected.map { |option| option["value"].to_i }).to eq [requester.id]
        expect(selected.text).to include("（現在の設定）")
      end

      it "残さない旧主催のメンバーを同じ送信で新たに指定すると、更新全体をエラーにする" do
        patch admin_event_path(event), params: {
          event: { community_id: jazz.id, keep_previous_primary_as_cohost: "0", songs_attributes: { "0" => { id: song.id, requested_by_customer_id: member_of(western).id } } }
        }

        expect(response.status).to eq 200
        expect(response.body).to include("有効なメンバーではありません")
        expect(Event.find(event.id).community_id).to eq western.id
        expect(Song.find(song.id).requested_by_customer_id).to be_nil
      end

      it "同じ送信で外す共催先のメンバーを新たに指定すると、更新全体をエラーにする" do
        event.update!(selected_cohost_community_ids: [japanese.id])

        patch admin_event_path(event), params: {
          event: { community_id: western.id, selected_cohost_community_ids: [""], songs_attributes: { "0" => { id: song.id, requested_by_customer_id: member_of(japanese).id } } }
        }

        expect(response.status).to eq 200
        expect(Event.find(event.id).all_hosting_community_ids).to eq [western.id, japanese.id]
        expect(Song.find(song.id).requested_by_customer_id).to be_nil
      end
    end

    it "管理画面で主催を変更した後は旧主催を削除でき、イベントは残る" do
      event.update!(selected_cohost_community_ids: [japanese.id])
      patch admin_event_path(event), params: { event: { community_id: japanese.id, keep_previous_primary_as_cohost: "1" } }
      sign_in FactoryBot.create(:customer, is_owner: :admin)

      expect { delete admin_community_path(western) }.to change(Community, :count).by(-1)

      expect(Event.find(event.id).all_hosting_community_ids).to eq [japanese.id]
    end

    it "新規作成は従来の単一選択のまま、開催コミュニティの行を作る" do
      get new_admin_event_path
      expect(Nokogiri::HTML(response.body).css("[name='event[selected_cohost_community_ids][]']")).to be_empty

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

    patch admin_event_path(event), params: { event: { selected_cohost_community_ids: [japanese.id] } }

    expect(Event.find(event.id).all_hosting_community_ids).to eq [western.id]
  end
end
