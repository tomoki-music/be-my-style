require 'rails_helper'

RSpec.describe "Public::Events", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:other_customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:community) { FactoryBot.create(:community) }
  let(:event) { FactoryBot.create(:event, :event_with_songs, customer: customer, community: community) }
  let(:song) { FactoryBot.create(:song, event: event) }

  describe 'ログイン済み' do
    before do
      customer.create_subscription!(status: "active", plan: "core")
      community.update!(owner_id: customer.id)
      CommunityOwner.find_or_create_by!(customer: customer, community: community)
      CommunityCustomer.find_or_create_by!(customer: customer, community: community)
      sign_in customer
    end
    context "event一覧ページ(index)が正しく表示される" do
      before do
        get public_events_path
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
    end
    context "event一覧は開催日の新しい順で表示される" do
      let!(:older_event) do
        FactoryBot.create(
          :event,
          :event_with_songs,
          customer: customer,
          community: community,
          event_name: "older event",
          event_start_time: 3.days.from_now,
          event_end_time: 3.days.from_now + 2.hours
        )
      end
      let!(:newer_event) do
        FactoryBot.create(
          :event,
          :event_with_songs,
          customer: customer,
          community: community,
          event_name: "newer event",
          event_start_time: 10.days.from_now,
          event_end_time: 10.days.from_now + 2.hours
        )
      end

      it "デフォルトでは開催日の新しい順になること" do
        get public_events_path

        expect(response.body.index("newer event")).to be < response.body.index("older event")
      end
    end
    context "event詳細ページ(show)が正しく表示される" do
      before do
        get public_event_path(event)
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
    end
    context "event新規作成ページ(new)が正しく表示される" do
      before do
        get new_public_event_path(community_id: community.id)
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
    end
    context "event新規作成(create)が正しく処理され登録される" do
      it "eventの作成が成功する" do
        expect do
          event
        end.to change(Event, :count).by(1)
      end
    end
    context "Premium由来コミュニティのイベント作成制限" do
      let(:premium_origin_community) { FactoryBot.create(:community, :premium_origin, owner_id: customer.id) }

      before do
        CommunityOwner.find_or_create_by!(customer: customer, community: premium_origin_community)
        CommunityCustomer.find_or_create_by!(customer: customer, community: premium_origin_community)
      end

      it "管理コミュニティ権限があればCoreユーザーでもPremium由来コミュニティで作成ページを表示できること" do
        get new_public_event_path(community_id: premium_origin_community.id)

        expect(response.status).to eq 200
      end

      it "管理コミュニティ権限があればCoreユーザーでもPremium由来コミュニティでイベントを作成できること" do
        expect do
          post public_events_path, params: event_create_params(premium_origin_community)
        end.to change(Event, :count).by(1)
      end

      it "PremiumユーザーはPremium由来コミュニティで作成ページを表示できること" do
        customer.subscription.update!(plan: "premium")

        get new_public_event_path(community_id: premium_origin_community.id)

        expect(response.status).to eq 200
      end

      context "管理コミュニティ権限のないユーザーの場合" do
        let(:unmanaged_premium_community) { FactoryBot.create(:community, :premium_origin, owner_id: other_customer.id) }

        before do
          CommunityCustomer.find_or_create_by!(customer: customer, community: unmanaged_premium_community)
        end

        it "Coreユーザーはnewでブロックされ、Premium案内が表示されること" do
          get new_public_event_path(community_id: unmanaged_premium_community.id)

          expect(response).to redirect_to(public_community_path(unmanaged_premium_community))
          follow_redirect!
          expect(response.body).to include("Premiumプランが必要です")
        end

        it "Coreユーザーはcreateでブロックされ、イベントが作成されないこと" do
          expect do
            post public_events_path, params: event_create_params(unmanaged_premium_community)
          end.not_to change(Event, :count)

          expect(response).to redirect_to(public_community_path(unmanaged_premium_community))
        end
      end
    end
    context "event編集ページ(edit)が正しく表示される" do
      it 'リクエストは200 OKとなること（投稿者本人である場合）' do
        get edit_public_event_path(event)
        expect(response.status).to eq 200
      end
      it 'リクエストは302 Foundとなること（投稿者本人でない場合）' do
        sign_in other_customer
        get edit_public_event_path(event)
        expect(response.status).to eq 302
      end
    end
    context "event編集(update)が正しく処理され登録される" do
      it '記事を編集できること(投稿者本人の場合)' do
        put public_event_path(event), params: {
          event: {
            customer_id: customer.id,
            community_id: community.id,
            event_name: "今回限定のセッション！",
            event_date: DateTime.now,
            entrance_fee: 1500,
            address: "埼玉県川口市",
            introduction: "今回限定のセッション開催です！",
          }
        }
        expect(event.reload.event_name).to eq '今回限定のセッション！'
        expect(event.reload.introduction).to eq '今回限定のセッション開催です！'
      end
      it 'リクエストは302 Foundとなること（投稿者本人でない場合）' do
        sign_in other_customer
        put public_event_path(event), params: {
          event: {
            event_name: "今回限定のセッション！",
            event_date: DateTime.now,
            entrance_fee: 1500,
            address: "埼玉県川口市",
            introduction: "今回限定のセッション開催です！",
          }
        }
        expect(response.status).to eq 302
      end
    end
    context "eventページを正しく削除(destroy)できる" do
      it '正しく削除できる（投稿者本人である場合）' do
        event
        expect do
          delete public_event_path(event)
        end.to change(Event, :count).by(-1)
      end
      it 'リクエストは302 Foundとなること（投稿者本人でない場合）' do
        sign_in other_customer
        delete public_event_path(event)
        expect(response.status).to eq 302
      end
    end
    context "event参加メンバーを正しく削除(delete)できる" do
      it '正しくメンバー削除できる' do
        event
        join_part = JoinPart.create(song_id: song.id, join_part_name: "vocal")
        JoinPartCustomer.create(customer_id: customer.id, join_part_id: join_part.id)
        expect do
          delete public_event_delete_path(event, customer_id: customer, join_part_id: join_part.id)
        end.to change(JoinPartCustomer, :count).by(-1)
      end
    end

    context "有料プラン月次特典(session_credit)の判定" do
      let(:join_part_a) { FactoryBot.create(:join_part, song: event.songs.first) }
      let(:another_event) do
        FactoryBot.create(:event, :event_with_songs, customer: customer, community: community, entrance_fee: 2000)
      end
      let(:join_part_b) { FactoryBot.create(:join_part, song: another_event.songs.first) }

      it "先月特典を利用していても今月はまだ未利用として表示され、1,500円が適用されること" do
        travel_to(Time.zone.local(2026, 6, 15, 12, 0, 0)) do
          post public_event_join_path(event), params: { join_part_ids: { "0" => join_part_a.id.to_s } }
        end

        travel_to(Time.zone.local(2026, 7, 10, 12, 0, 0)) do
          get public_event_path(another_event)
        end

        expect(response.body).to include("今月の特典対象")
        expect(response.body).to include("-1,500円")
      end

      it "今月すでに特典を利用済みの場合、別イベントでは今月分は利用済みと表示されること" do
        travel_to(Time.zone.local(2026, 7, 3, 12, 0, 0)) do
          post public_event_join_path(event), params: { join_part_ids: { "0" => join_part_a.id.to_s } }
        end

        travel_to(Time.zone.local(2026, 7, 20, 12, 0, 0)) do
          get public_event_path(another_event)
        end

        expect(response.body).to include("今月特典は使用済み")
      end

      it "同月内に2つのイベントへ参加登録しても特典が二重に消化されないこと" do
        travel_to(Time.zone.local(2026, 7, 3, 12, 0, 0)) do
          post public_event_join_path(event), params: { join_part_ids: { "0" => join_part_a.id.to_s } }
          post public_event_join_path(another_event), params: { join_part_ids: { "0" => join_part_b.id.to_s } }
        end

        credited_count = JoinPartCustomer.where(customer_id: customer.id, session_credit_applied: true).count
        expect(credited_count).to eq 1
      end

      it "特典適用済みの参加を取消し、同イベントの他パートへの参加が残っていない場合は特典が消滅すること(既存仕様)" do
        travel_to(Time.zone.local(2026, 7, 3, 12, 0, 0)) do
          post public_event_join_path(event), params: { join_part_ids: { "0" => join_part_a.id.to_s } }
        end
        expect(JoinPartCustomer.where(customer_id: customer.id, session_credit_applied: true).count).to eq 1

        travel_to(Time.zone.local(2026, 7, 5, 12, 0, 0)) do
          delete public_event_delete_path(event, customer_id: customer.id, join_part_id: join_part_a.id)
        end
        expect(JoinPartCustomer.where(customer_id: customer.id, session_credit_applied: true).count).to eq 0

        travel_to(Time.zone.local(2026, 7, 20, 12, 0, 0)) do
          expect(customer.session_credit_available_for?).to eq true
        end
      end

      it "特典適用済みの参加を取消しても同イベントの別パートに参加が残っている場合は特典が引き継がれること(既存仕様)" do
        second_song = FactoryBot.create(:song, event: event)
        join_part_c = FactoryBot.create(:join_part, song: second_song)

        travel_to(Time.zone.local(2026, 7, 3, 12, 0, 0)) do
          post public_event_join_path(event), params: {
            join_part_ids: { "0" => join_part_a.id.to_s, "1" => join_part_c.id.to_s }
          }
        end
        expect(JoinPartCustomer.where(customer_id: customer.id, session_credit_applied: true).count).to eq 1

        travel_to(Time.zone.local(2026, 7, 5, 12, 0, 0)) do
          delete public_event_delete_path(event, customer_id: customer.id, join_part_id: join_part_a.id)
        end

        remaining = JoinPartCustomer.find_by(customer_id: customer.id, join_part_id: join_part_c.id)
        expect(remaining.session_credit_applied?).to eq true

        travel_to(Time.zone.local(2026, 7, 20, 12, 0, 0)) do
          expect(customer.session_credit_available_for?).to eq false
        end
      end
    end
  end

  describe '非ログイン' do
    context "events一覧ページ(index)へ遷移されない" do
      before do
        get public_events_path
      end
      it 'リクエストは302 Foundとなること' do
        expect(response.status).to eq 302
      end
    end
    context "event詳細ページ(show)へ遷移されない" do
      before do
        get public_event_path(event)
      end
      it 'リクエストは302 Foundとなること' do
        expect(response.status).to eq 302
      end
    end
    context "event新規作成ページ(new)へ遷移されない" do
      before do
        get new_public_event_path
      end
      it 'リクエストは302 OKとなること' do
        expect(response.status).to eq 302
      end
    end
    context "event新規作成(create)が正しく処理されない" do
      it "eventの作成に失敗する" do
        post public_events_path, params: {
          event: {
            customer_id: customer.id,
            community_id: community.id,
            event_name: "セッション開催！",
            event_date: DateTime.now,
            entrance_fee: 1500,
            address: "埼玉県川口市",
            introduction: "邦楽と洋楽のコピーセッション開催です！",
          }
        }
        expect(response.status).to eq 302
      end
    end
    context "event編集ページ(edit)が正しく表示されない" do
      it 'リクエストは302 となること' do
        get edit_public_event_path(event)
        expect(response.status).to eq 302
      end
    end
    context "event編集(update)が正しく処理され登録されない" do
      it 'リクエストは302 Foundとなること' do
        put public_event_path(event), params: {
          event: {
            event_name: "今回限定のセッション！",
            event_date: DateTime.now,
            entrance_fee: 1500,
            address: "埼玉県川口市",
            introduction: "今回限定のセッション開催です！",
          }
        }
        expect(response.status).to eq 302
      end
    end
    context "eventページを正しく削除(destroy)できない" do
      it 'リクエストは302 Foundとなること' do
        delete public_event_path(event)
        expect(response.status).to eq 302
      end
    end
  end

  def event_create_params(community)
    {
      event: {
        community_id: community.id,
        event_name: "Premiumコミュニティ限定セッション",
        event_start_time: 7.days.from_now,
        event_end_time: 7.days.from_now + 2.hours,
        event_entry_deadline: 6.days.from_now,
        entrance_fee: 1500,
        place: "MMMstudio",
        address: "埼玉県さいたま市",
        introduction: "Premiumコミュニティのイベントです",
        songs_attributes: {
          "0" => {
            song_name: "Session Song",
            performance_time: "5:00",
            join_parts_attributes: {
              "0" => { join_part_name: "Vocal" }
            }
          }
        }
      }
    }
  end
end
