require "rails_helper"

RSpec.describe "イベントの開催コミュニティ(公開画面)", type: :request do
  let(:organizer) { FactoryBot.create(:customer) }
  let(:western) { FactoryBot.create(:community, name: "洋楽セッション") }
  let(:japanese) { FactoryBot.create(:community, name: "邦楽セッション") }
  let(:jazz) { FactoryBot.create(:community, name: "ジャズセッション") }
  let(:event) do
    FactoryBot.create(:event, :event_with_songs,
      customer: organizer, community: western, event_name: "合同セッション",
      event_start_time: 30.days.from_now, event_end_time: 30.days.from_now + 2.hours, event_entry_deadline: 20.days.from_now)
  end
  let(:song) { event.songs.first }
  let!(:vocal) { FactoryBot.create(:join_part, song: song, join_part_name: "ボーカル") }
  let!(:guitar) { FactoryBot.create(:join_part, song: song, join_part_name: "ギター") }

  def member_of(*communities)
    FactoryBot.create(:customer).tap do |customer|
      communities.each { |community| CommunityCustomer.create!(customer: customer, community: community) }
    end
  end

  def host_both
    event.update!(selected_cohost_community_ids: [japanese.id])
  end

  def join(part)
    post public_event_join_path(event), params: { join_part_ids: { "0" => part.id.to_s } }
  end

  describe "編集画面" do
    it "サイト管理者には主催を固定表示し、共催先だけを既存の設定で初期選択して表示する" do
      host_both
      jazz
      sign_in FactoryBot.create(:customer, is_owner: :admin)

      get edit_public_event_path(event)

      page = Nokogiri::HTML(response.body)
      boxes = page.css("input[type=checkbox][name='event[selected_cohost_community_ids][]']")
      expect(boxes.map { |box| box["value"].to_i }).to contain_exactly(japanese.id, jazz.id)
      expect(boxes.select { |box| box["checked"] }.map { |box| box["value"].to_i }).to eq [japanese.id]
      expect(page.css(".event-hosting-communities__primary").text).to include("主催", "洋楽セッション", "固定")
      expect(page.css("[name='event[community_id]']")).to be_empty
    end

    it "イベント作成者には選択欄を出さず、主催と共催を区別して名前だけを表示する" do
      host_both
      sign_in organizer

      get edit_public_event_path(event)

      page = Nokogiri::HTML(response.body)
      expect(page.css("[name='event[selected_cohost_community_ids][]']")).to be_empty
      expect(page.css("[name='event[community_id]']")).to be_empty
      expect(response.body).to include("主催", "共催", "洋楽セッション", "邦楽セッション")
    end
  end

  describe "更新" do
    let(:tampered_params) do
      {
        event_name: "名前だけ変更",
        community_id: jazz.id,
        selected_cohost_community_ids: [jazz.id],
        keep_previous_primary_as_cohost: "0",
        selected_hosting_community_ids: [jazz.id],
        event_community_ids: [jazz.id],
        hosting_community_ids: [jazz.id],
        community_ids: [jazz.id]
      }
    end

    it "サイト管理者は共催先を複数設定でき、解除もできる" do
      sign_in FactoryBot.create(:customer, is_owner: :admin)

      patch public_event_path(event), params: { event: { selected_cohost_community_ids: ["", japanese.id, jazz.id] } }
      expect(response).to redirect_to(public_event_path(event))
      expect(event.reload.all_hosting_community_ids).to eq [western.id, japanese.id, jazz.id]

      patch public_event_path(event), params: { event: { selected_cohost_community_ids: ["", jazz.id] } }
      expect(event.reload.all_hosting_community_ids).to eq [western.id, jazz.id]
    end

    it "サイト管理者が共催先を全て外しても主催は残る" do
      host_both
      sign_in FactoryBot.create(:customer, is_owner: :admin)

      patch public_event_path(event), params: { event: { selected_cohost_community_ids: [""] } }

      expect(response).to redirect_to(public_event_path(event))
      expect(Event.find(event.id).all_hosting_community_ids).to eq [western.id]
    end

    it "サイト管理者が主催を外す直接リクエストを送っても、主催の解除も自動切り替えも起きない" do
      host_both
      sign_in FactoryBot.create(:customer, is_owner: :admin)

      patch public_event_path(event), params: { event: { selected_cohost_community_ids: [jazz.id], selected_hosting_community_ids: [jazz.id] } }

      fresh = Event.find(event.id)
      expect(fresh.community_id).to eq western.id
      expect(fresh.all_hosting_community_ids).to eq [western.id, jazz.id]
      expect(fresh.event_communities.pluck(:community_id)).to include(western.id)
    end

    it "サイト管理者が存在しないIDや不正な値を送るとエラーにする" do
      sign_in FactoryBot.create(:customer, is_owner: :admin)

      patch public_event_path(event), params: { event: { selected_cohost_community_ids: [japanese.id, 999_999_999] } }
      expect(response.status).to eq 200
      expect(response.body).to include("存在しないコミュニティ")

      patch public_event_path(event), params: { event: { selected_cohost_community_ids: ["abc"] } }
      expect(response.status).to eq 200
      expect(response.body).to include("共催先の指定が正しくありません")
      expect(Event.find(event.id).all_hosting_community_ids).to eq [western.id]
    end

    it "サイト管理者でも公開画面からは主催を変更できない(旧主催を残す指定も無視する)" do
      sign_in FactoryBot.create(:customer, is_owner: :admin)

      patch public_event_path(event), params: { event: { community_id: jazz.id, keep_previous_primary_as_cohost: "1" } }

      expect(event.reload.community_id).to eq western.id
      expect(event.all_hosting_community_ids).to eq [western.id]
    end

    shared_examples "改ざんしても開催コミュニティを変更できない" do
      it "ほかの項目だけ更新され、主催・開催コミュニティは変わらない" do
        host_both
        sign_in actor

        patch public_event_path(event), params: { event: tampered_params }

        expect(response).to redirect_to(public_event_path(event))
        fresh = Event.find(event.id)
        expect(fresh.event_name).to eq "名前だけ変更"
        expect(fresh.community_id).to eq western.id
        expect(fresh.all_hosting_community_ids).to eq [western.id, japanese.id]
      end
    end

    context "イベント作成者" do
      let(:actor) { organizer }

      include_examples "改ざんしても開催コミュニティを変更できない"
    end

    context "主催コミュニティのオーナー" do
      let(:actor) do
        FactoryBot.create(:customer, is_owner: :community_owner).tap do |owner|
          CommunityOwner.create!(customer: owner, community: western)
          western.update!(owner_id: owner.id)
        end
      end

      include_examples "改ざんしても開催コミュニティを変更できない"
    end

    context "主催コミュニティのイベント編集者" do
      let(:actor) do
        FactoryBot.create(:customer, is_owner: :manager).tap do |editor|
          CommunityEventEditor.create!(customer: editor, community: western)
        end
      end

      include_examples "改ざんしても開催コミュニティを変更できない"
    end

    it "編集権限の無い一般ユーザーは更新自体できない" do
      host_both
      sign_in member_of(western)

      patch public_event_path(event), params: { event: tampered_params }

      fresh = Event.find(event.id)
      expect(fresh.event_name).to eq "合同セッション"
      expect(fresh.all_hosting_community_ids).to eq [western.id, japanese.id]
    end

    it "追加された開催コミュニティのオーナーは編集も削除もできない" do
      host_both
      added_owner = FactoryBot.create(:customer, is_owner: :community_owner)
      CommunityOwner.create!(customer: added_owner, community: japanese)
      japanese.update!(owner_id: added_owner.id)
      sign_in added_owner

      get edit_public_event_path(event)
      expect(response).to redirect_to(public_events_path)

      patch public_event_path(event), params: { event: { event_name: "乗っ取り" } }
      expect(event.reload.event_name).to eq "合同セッション"

      expect { delete public_event_path(event) }.not_to change(Event, :count)
    end

    it "作成者がフォームと同じ内容で通常編集しても設定は維持される" do
      host_both
      sign_in organizer

      get edit_public_event_path(event)
      patch public_event_path(event), params: { event: { place: "新しい会場" } }

      fresh = Event.find(event.id)
      expect(fresh.place).to eq "新しい会場"
      expect(fresh.all_hosting_community_ids).to eq [western.id, japanese.id]
    end
  end

  describe "新規作成" do
    let(:create_params) do
      {
        event: {
          community_id: western.id,
          event_name: "新規イベント",
          event_start_time: 30.days.from_now,
          event_end_time: 30.days.from_now + 2.hours,
          event_entry_deadline: 20.days.from_now,
          entrance_fee: 1000,
          place: "スタジオ",
          address: "埼玉県さいたま市",
          selected_cohost_community_ids: [jazz.id],
          songs_attributes: { "0" => { song_name: "曲", artist_name: "アーティスト", join_parts_attributes: { "0" => { join_part_name: "ボーカル" } } } }
        }
      }
    end

    it "作成時は主催コミュニティのみが開催コミュニティになり、追加指定は無視される" do
      creator = FactoryBot.create(:customer, is_owner: :admin)
      sign_in creator

      expect { post public_events_path, params: create_params }.to change(Event, :count).by(1)

      created = Event.order(:id).last
      expect(created.community_id).to eq western.id
      expect(created.event_communities.pluck(:community_id)).to eq [western.id]
    end

    it "新規作成画面は従来の所属コミュニティ欄のまま" do
      sign_in FactoryBot.create(:customer, is_owner: :admin)

      get new_public_event_path(community_id: western.id)

      expect(response.body).to include("所属コミュニティ")
      expect(Nokogiri::HTML(response.body).css("[name='event[selected_cohost_community_ids][]']")).to be_empty
    end

    it "コピーでは主催コミュニティだけを引き継ぐ(追加の開催コミュニティは複製しない)" do
      host_both
      sign_in organizer

      get copy_public_event_path(event)

      expect(response.status).to eq 200
      expect(Nokogiri::HTML(response.body).css("[name='event[community_id]']").first["value"].to_i).to eq western.id
      expect(response.body).not_to include("邦楽セッション")
    end
  end

  describe "参加" do
    before { host_both }

    it "洋楽だけの所属者も邦楽だけの所属者も参加できる" do
      [member_of(western), member_of(japanese)].each do |customer|
        sign_in customer

        expect { join(vocal) }.to change { JoinPartCustomer.where(customer: customer).count }.by(1)
        expect(response).to redirect_to(public_event_path(event))
        sign_out customer
      end
    end

    it "両方に所属していてもエントリーと参加者一覧が重複しない" do
      both = member_of(western, japanese)
      sign_in both

      expect do
        join(vocal)
        join(vocal)
      end.to change { JoinPartCustomer.where(customer: both).count }.by(1)

      expect(event.participating_customers.where(id: both.id).count).to eq 1
    end

    it "どちらにも所属していないユーザーは参加できず、既存と同じ案内を受ける" do
      outsider = member_of(jazz)
      sign_in outsider

      expect { join(vocal) }.not_to change(JoinPartCustomer, :count)
      expect(response).to redirect_to(public_community_path(western))
      expect(flash[:alert]).to eq "まずこちらのコミュニティに参加してください"
    end

    it "参加申請中のユーザーは参加できない" do
      applicant = FactoryBot.create(:customer)
      Permit.create!(customer: applicant, community: japanese)
      sign_in applicant

      expect { join(vocal) }.not_to change(JoinPartCustomer, :count)
    end

    it "追加された開催コミュニティの所属者へ通知は増やさない" do
      japanese_member = member_of(japanese)

      expect { event.update!(selected_cohost_community_ids: [japanese.id, jazz.id]) }.not_to change(Notification, :count)
      expect(japanese_member.passive_notifications).to be_empty
    end
  end

  describe "コミュニティが1つの既存イベント" do
    it "所属者は参加でき、非所属者は従来の案内になる" do
      member = member_of(western)
      sign_in member
      expect { join(vocal) }.to change(JoinPartCustomer, :count).by(1)
      sign_out member

      outsider = member_of(japanese)
      sign_in outsider
      expect { join(guitar) }.not_to change(JoinPartCustomer, :count)
      expect(response).to redirect_to(public_community_path(western))
    end

    it "詳細画面と楽曲画面は従来の文言で表示する" do
      sign_in member_of(japanese)

      get public_event_path(event)
      expect(response.body).to include("※このイベントは【洋楽セッション】に参加している必要があります。")

      get public_event_song_path(event, song)
      expect(response.body).to include("参加するには、開催コミュニティへの参加が必要です。")
      expect(response.body).to include("まずこちらのコミュニティに参加してください")
    end
  end

  describe "表示" do
    before { host_both }

    it "詳細画面は全ての開催コミュニティをリンク付きで表示し、OR 条件を案内する" do
      sign_in member_of(jazz)

      get public_event_path(event)

      page = Nokogiri::HTML(response.body)
      [western, japanese].each do |community|
        expect(page.css("a[href='#{public_community_path(community)}']").map(&:text)).to include(community.name)
      end
      expect(response.body).to include("【洋楽セッション】【邦楽セッション】のいずれかに参加している必要があります。")
    end

    it "楽曲画面はどちらにも所属しない人へ各コミュニティへのリンクを出す" do
      sign_in member_of(jazz)

      get public_event_song_path(event, song)

      expect(response.body).to include(public_community_path(western), public_community_path(japanese))
      expect(response.body).to include("いずれかへの参加が必要です")
    end

    it "楽曲画面は追加された開催コミュニティの所属者に参加ボタンを出す" do
      sign_in member_of(japanese)

      get public_event_song_path(event, song)

      expect(response.body).to include("参加確認画面へ")
    end

    it "一覧は両方のコミュニティで絞り込めて、イベントは1件だけ表示する" do
      sign_in member_of(jazz)

      [western, japanese].each do |community|
        get public_events_path(community_id: community.id)
        expect(Nokogiri::HTML(response.body).css(".event-index-container .card.mb-5").size).to eq 1
        expect(response.body).to include("洋楽セッション / 邦楽セッション")
      end

      get public_events_path(community_id: jazz.id)
      expect(Nokogiri::HTML(response.body).css(".event-index-container .card.mb-5").size).to eq 0
    end

    it "追加されたコミュニティの名前でもキーワード検索できて、重複しない" do
      sign_in member_of(jazz)

      get public_events_path(keyword: "邦楽")

      expect(Nokogiri::HTML(response.body).css(".event-index-container .card.mb-5").size).to eq 1
    end

    it "追加されたコミュニティの詳細ページにも開催予定として表示する" do
      sign_in member_of(japanese)

      get public_community_path(japanese)

      expect(response.body).to include("合同セッション")
    end
  end

  describe "コミュニティの削除" do
    let(:owner) { FactoryBot.create(:customer, is_owner: :community_owner) }

    it "共催イベントの主催コミュニティはオーナーでも削除できず、対象イベントを案内する" do
      host_both
      CommunityOwner.create!(customer: owner, community: western)
      western.update!(owner_id: owner.id)
      sign_in owner

      expect { delete public_community_path(western) }.not_to change(Community, :count)

      expect(response).to redirect_to(public_community_path(western))
      follow_redirect!
      expect(response.body).to include("先に対象イベントの主催コミュニティを変更してください")
      expect(response.body).to include("「合同セッション」(ID: #{event.id})")
    end

    it "共催先としてのみ設定されたコミュニティは削除でき、イベントと参加記録は残る" do
      host_both
      CommunityOwner.create!(customer: owner, community: japanese)
      japanese.update!(owner_id: owner.id)
      participant = member_of(japanese)
      JoinPartCustomer.create!(customer: participant, join_part: vocal)
      sign_in owner

      expect { delete public_community_path(japanese) }.to change(Community, :count).by(-1)

      fresh = Event.find(event.id)
      expect(fresh.all_hosting_community_ids).to eq [western.id]
      expect(JoinPartCustomer.exists?(customer: participant, join_part: vocal)).to eq true
    end
  end

  describe "閲覧範囲" do
    it "非所属者のイベント閲覧・編集権限は開催コミュニティの追加で変わらない" do
      host_both
      outsider = member_of(jazz)
      sign_in outsider

      get public_event_path(event)
      expect(response.status).to eq 200

      get edit_public_event_path(event)
      expect(response).to redirect_to(public_events_path)
    end
  end
end
