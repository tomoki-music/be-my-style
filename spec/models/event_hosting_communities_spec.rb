require "rails_helper"

RSpec.describe "Event の開催コミュニティ", type: :model do
  let(:organizer) { FactoryBot.create(:customer) }
  let(:western) { FactoryBot.create(:community, name: "洋楽セッション") }
  let(:japanese) { FactoryBot.create(:community, name: "邦楽セッション") }
  let(:jazz) { FactoryBot.create(:community, name: "ジャズセッション") }
  let(:event) { FactoryBot.create(:event, :event_with_songs, customer: organizer, community: western) }

  def member_of(*communities)
    FactoryBot.create(:customer).tap do |customer|
      communities.each { |community| CommunityCustomer.create!(customer: customer, community: community) }
    end
  end

  def set_cohosts(*communities)
    event.update(selected_cohost_community_ids: communities.map(&:id).map(&:to_s))
  end

  describe "作成時" do
    it "主催コミュニティが開催コミュニティの1件目になる" do
      expect(event.event_communities.pluck(:community_id)).to eq [western.id]
      expect(event.all_hosting_communities).to eq [western]
    end
  end

  describe "#selected_cohost_community_ids=" do
    it "共催先の追加と解除を反映し、主催は変えない" do
      expect(set_cohosts(japanese, jazz)).to eq true
      expect(event.reload.all_hosting_community_ids).to eq [western.id, japanese.id, jazz.id]

      expect(set_cohosts(jazz)).to eq true
      expect(event.reload.all_hosting_community_ids).to eq [western.id, jazz.id]
      expect(event.community_id).to eq western.id
    end

    it "同じIDが重複していても1件だけ登録する" do
      event.update!(selected_cohost_community_ids: [japanese.id, japanese.id.to_s])

      expect(EventCommunity.where(event: event, community: japanese).count).to eq 1
    end

    it "共催先を全て外しても主催は残るので0件にならない" do
      set_cohosts(japanese)

      expect(event.update(selected_cohost_community_ids: [""])).to eq true
      expect(event.reload.all_hosting_community_ids).to eq [western.id]
      expect(event.event_communities.pluck(:community_id)).to eq [western.id]
    end

    it "主催を含まない指定をしても主催は解除も切り替えもされない" do
      expect(event.update(selected_cohost_community_ids: [japanese.id])).to eq true

      fresh = Event.find(event.id)
      expect(fresh.community_id).to eq western.id
      expect(fresh.event_communities.pluck(:community_id)).to contain_exactly(western.id, japanese.id)
    end

    it "主催のIDを含めても二重に登録しない" do
      event.update!(selected_cohost_community_ids: [western.id, japanese.id])

      expect(event.reload.event_communities.pluck(:community_id)).to contain_exactly(western.id, japanese.id)
      expect(event.selected_cohost_community_ids).to eq [japanese.id]
    end

    it "存在しないIDを1件でも含むと全体を反映しない" do
      expect(event.update(selected_cohost_community_ids: [japanese.id, 999_999_999])).to eq false
      expect(event.errors.full_messages).to include("存在しないコミュニティが共催先に含まれています")
      expect(Event.find(event.id).all_hosting_community_ids).to eq [western.id]
    end

    it "bigint に収まらないIDや数値でない値を拒否する" do
      expect(event.update(selected_cohost_community_ids: ["99999999999999999999999"])).to eq false
      expect(event.update(selected_cohost_community_ids: ["abc"])).to eq false
      expect(event.update(selected_cohost_community_ids: ["#{japanese.id} OR 1=1"])).to eq false
      expect(event.update(selected_cohost_community_ids: [0])).to eq false
      expect(Event.find(event.id).all_hosting_community_ids).to eq [western.id]
    end

    it "別ドメインのコミュニティは追加できない" do
      business = FactoryBot.create(:community, domain: Domain.find_or_create_by!(name: "business"))

      expect(event.update(selected_cohost_community_ids: [business.id])).to eq false
      expect(Event.find(event.id).all_hosting_community_ids).to eq [western.id]
    end

    it "他の項目の検証に失敗したら共催先も反映しない" do
      expect(event.update(event_name: "", selected_cohost_community_ids: [japanese.id])).to eq false
      expect(Event.find(event.id).all_hosting_community_ids).to eq [western.id]
    end
  end

  describe "主催の変更(community_id)" do
    before { set_cohosts(japanese) }

    it "残す指定があれば旧主催は共催先になり、新しい主催は開催コミュニティに含まれる" do
      event.update!(community_id: jazz.id, keep_previous_primary_as_cohost: "1")

      fresh = Event.find(event.id)
      expect(fresh.community_id).to eq jazz.id
      expect(fresh.event_communities.pluck(:community_id)).to contain_exactly(western.id, japanese.id, jazz.id)
      expect(fresh.all_hosting_community_ids.first).to eq jazz.id
    end

    it "残さない指定なら旧主催は開催コミュニティから外れ、ほかの共催先は残る" do
      event.update!(community_id: jazz.id, keep_previous_primary_as_cohost: "0")

      expect(Event.find(event.id).event_communities.pluck(:community_id)).to contain_exactly(japanese.id, jazz.id)
    end

    it "指定が無いときは旧主催を残さない" do
      event.update!(community_id: jazz.id)

      expect(Event.find(event.id).event_communities.pluck(:community_id)).to contain_exactly(japanese.id, jazz.id)
    end

    it "共催先を主催に昇格すると、重複せず旧主催を残せる" do
      event.update!(community_id: japanese.id, selected_cohost_community_ids: [japanese.id], keep_previous_primary_as_cohost: "1")

      fresh = Event.find(event.id)
      expect(fresh.community_id).to eq japanese.id
      expect(fresh.event_communities.pluck(:community_id)).to contain_exactly(japanese.id, western.id)
    end

    it "主催を変えないときは残す指定があっても共催先の内容は変わらない" do
      event.update!(place: "別会場", keep_previous_primary_as_cohost: "1")

      expect(Event.find(event.id).all_hosting_community_ids).to eq [western.id, japanese.id]
    end

    it "別ドメインへの変更で旧主催を残す指定はエラーになり、残さなければ変更できる" do
      business = FactoryBot.create(:community, domain: Domain.find_or_create_by!(name: "business"))

      expect(event.update(community_id: business.id, keep_previous_primary_as_cohost: "1", selected_cohost_community_ids: [""])).to eq false
      expect(Event.find(event.id).community_id).to eq western.id

      expect(Event.find(event.id).update(community_id: business.id, keep_previous_primary_as_cohost: "0", selected_cohost_community_ids: [""])).to eq true
      expect(Event.find(event.id).all_hosting_community_ids).to eq [business.id]
    end
  end

  describe "#community_member?" do
    before { set_cohosts(japanese) }

    it "どちらか一方の所属で true になる" do
      expect(event.community_member?(member_of(western))).to eq true
      expect(event.community_member?(member_of(japanese))).to eq true
      expect(event.community_member?(member_of(western, japanese))).to eq true
    end

    it "どちらにも所属していなければ false" do
      expect(event.community_member?(member_of(jazz))).to eq false
      expect(event.community_member?(nil)).to eq false
    end

    it "参加申請中(Permit)は所属として扱わない" do
      applicant = FactoryBot.create(:customer)
      Permit.create!(customer: applicant, community: japanese)

      expect(event.community_member?(applicant)).to eq false
    end

    it "行が無い(旧コードが作成した)イベントでも主催コミュニティで判定する" do
      EventCommunity.where(event: event).delete_all
      fresh = Event.find(event.id)

      expect(fresh.community_member?(member_of(western))).to eq true
      expect(fresh.community_member?(member_of(japanese))).to eq false
      expect(Event.hosted_by(western.id)).to include(fresh)
    end
  end

  describe ".hosted_by / Community#hosted_events" do
    before { set_cohosts(japanese) }

    it "両方のコミュニティから同じイベントを重複なく取得する" do
      expect(western.hosted_events).to contain_exactly(event)
      expect(japanese.hosted_events).to contain_exactly(event)
      expect(jazz.hosted_events).to be_empty
      expect(Event.hosted_by([western.id, japanese.id]).to_a).to eq [event]
    end

    it "Community#events は主催イベントだけのまま" do
      expect(western.events).to contain_exactly(event)
      expect(japanese.events).to be_empty
    end
  end

  describe "権限" do
    before { set_cohosts(japanese) }

    it "追加された開催コミュニティの運営者・イベント編集者には権限を与えない" do
      added_owner = FactoryBot.create(:customer, is_owner: :community_owner)
      CommunityOwner.create!(customer: added_owner, community: japanese)
      japanese.update!(owner_id: added_owner.id)
      added_editor = FactoryBot.create(:customer, is_owner: :manager)
      CommunityEventEditor.create!(customer: added_editor, community: japanese)

      [added_owner, added_editor].each do |customer|
        expect(customer.can_edit_event?(event)).to eq false
        expect(customer.can_destroy_event?(event)).to eq false
      end
    end

    it "主催コミュニティの運営者の権限は維持する" do
      main_owner = FactoryBot.create(:customer, is_owner: :community_owner)
      CommunityOwner.create!(customer: main_owner, community: western)
      western.update!(owner_id: main_owner.id)

      expect(main_owner.can_edit_event?(event)).to eq true
      expect(main_owner.can_destroy_event?(event)).to eq true
    end
  end

  describe "通知・メンションの宛先" do
    before { set_cohosts(japanese) }

    it "リマインド送信先とメンション候補は主催コミュニティのメンバーのまま" do
      western_member = member_of(western)
      japanese_member = member_of(japanese)

      expect(EventDeadlineReminders::RecipientResolver.call(event)).to include(western_member)
      expect(EventDeadlineReminders::RecipientResolver.call(event)).not_to include(japanese_member)
      expect(event.mentionable_community_members).to include(western_member)
      expect(event.mentionable_community_members).not_to include(japanese_member)
    end
  end

  describe "所属条件を参照する関連処理" do
    before { set_cohosts(japanese) }

    it "自己申告の演奏可能曲は、追加された開催コミュニティの所属者も選べて重複しない" do
      song = event.songs.first

      expect(member_of(japanese).eligible_songs_for_song_part).to include(song)
      expect(member_of(western, japanese).eligible_songs_for_song_part.where(id: song.id).count).to eq 1
      expect(member_of(jazz).eligible_songs_for_song_part).not_to include(song)
    end

    it "リクエストした人は、いずれかの開催コミュニティの有効メンバーを指定できる" do
      song = event.songs.first

      expect(song.update(requested_by_customer_id: member_of(japanese).id)).to eq true
      expect(song.update(requested_by_customer_id: member_of(jazz).id)).to eq false
    end

    it "両方に所属していても hosting_community_members は1人だけ返す" do
      both = member_of(western, japanese)

      expect(event.hosting_community_members.where(id: both.id).count).to eq 1
      expect(event.hosting_community_members.to_a.count(both)).to eq 1
    end
  end

  describe "削除" do
    before { set_cohosts(japanese) }

    it "共催先としてのみ設定されたコミュニティを削除しても、イベントと参加記録は残る" do
      part = FactoryBot.create(:join_part, song: event.songs.first)
      participant = member_of(japanese)
      JoinPartCustomer.create!(customer: participant, join_part: part)

      expect(japanese.destroy).to be_truthy

      expect(Event.exists?(event.id)).to eq true
      expect(event.reload.all_hosting_community_ids).to eq [western.id]
      expect(JoinPartCustomer.exists?(customer: participant, join_part: part)).to eq true
    end

    it "共催イベントを主催しているコミュニティは削除できず、対象イベントを案内する" do
      expect(western.destroy).to eq false

      expect(Community.exists?(western.id)).to eq true
      expect(Event.exists?(event.id)).to eq true
      message = western.errors.full_messages.join
      expect(message).to include("先に対象イベントの主催コミュニティを変更してください")
      expect(message).to include("「#{event.event_name}」(ID: #{event.id})")
    end

    it "拒否されたときはメンバーなどの関連も消さない" do
      member = member_of(western)

      western.destroy

      expect(CommunityCustomer.exists?(customer: member, community: western)).to eq true
    end

    it "主催を変更すれば、旧主催のコミュニティを削除できてイベントは残る" do
      event.update!(community_id: japanese.id, keep_previous_primary_as_cohost: "1")

      expect(Community.find(western.id).destroy).to be_truthy
      expect(Event.find(event.id).all_hosting_community_ids).to eq [japanese.id]
    end

    it "共催先の無いイベントだけを主催するコミュニティは従来どおりイベントごと削除する" do
      solo_community = FactoryBot.create(:community)
      solo_event = FactoryBot.create(:event, :event_with_songs, community: solo_community)

      expect(solo_community.destroy).to be_truthy
      expect(Event.exists?(solo_event.id)).to eq false
    end

    it "案内する対象イベントは10件までで、残りは件数で示す" do
      11.times do
        FactoryBot.create(:event, :event_with_songs, community: jazz).update!(selected_cohost_community_ids: [japanese.id])
      end

      expect(jazz.destroy).to eq false
      expect(jazz.errors.full_messages.join).to include("ほか1件")
    end

    it "イベントを削除すると中間テーブルの行も消える" do
      expect { event.destroy! }.to change { EventCommunity.where(community: japanese).count }.from(1).to(0)
    end

    it "DB の一意制約で同じ組み合わせを防ぐ" do
      expect do
        EventCommunity.new(event: event, community: japanese).save!(validate: false)
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
