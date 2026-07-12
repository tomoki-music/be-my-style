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

    context "有料プラン月次特典(session_credit)の判定 - 開催月基準" do
      let(:event) do
        FactoryBot.create(
          :event, :event_with_songs, customer: customer, community: community,
          event_start_time: Time.zone.local(2026, 7, 25, 19, 0, 0),
          event_end_time: Time.zone.local(2026, 7, 25, 21, 0, 0),
          event_entry_deadline: Time.zone.local(2026, 7, 20, 0, 0, 0)
        )
      end
      let(:join_part_a) { FactoryBot.create(:join_part, song: event.songs.first) }

      let(:another_event) do
        FactoryBot.create(
          :event, :event_with_songs, customer: customer, community: community, entrance_fee: 2000,
          event_start_time: Time.zone.local(2026, 8, 22, 19, 0, 0),
          event_end_time: Time.zone.local(2026, 8, 22, 21, 0, 0),
          event_entry_deadline: Time.zone.local(2026, 8, 15, 0, 0, 0)
        )
      end
      let(:join_part_b) { FactoryBot.create(:join_part, song: another_event.songs.first) }

      # `another_event`と同じ開催月(8月)だが別イベント。開催月内での二重適用防止の検証に使う。
      let(:same_month_event) do
        FactoryBot.create(
          :event, :event_with_songs, customer: customer, community: community, entrance_fee: 2000,
          event_start_time: Time.zone.local(2026, 8, 10, 19, 0, 0),
          event_end_time: Time.zone.local(2026, 8, 10, 21, 0, 0),
          event_entry_deadline: Time.zone.local(2026, 8, 5, 0, 0, 0)
        )
      end
      let(:join_part_c) { FactoryBot.create(:join_part, song: same_month_event.songs.first) }

      it "ケース1: 同じ日に申込んでも開催月が異なれば(7月/8月)両方に1,500円特典が適用されること" do
        travel_to(Time.zone.local(2026, 7, 11, 12, 0, 0)) do
          post public_event_join_path(event), params: { join_part_ids: { "0" => join_part_a.id.to_s } }
          post public_event_join_path(another_event), params: { join_part_ids: { "0" => join_part_b.id.to_s } }
        end

        first = JoinPartCustomer.find_by(customer_id: customer.id, join_part_id: join_part_a.id)
        second = JoinPartCustomer.find_by(customer_id: customer.id, join_part_id: join_part_b.id)

        expect(first.session_credit_applied?).to eq true
        expect(first.session_credit_amount).to eq 1500
        expect(second.session_credit_applied?).to eq true
        expect(second.session_credit_amount).to eq 1500
      end

      it "ケース2: 申込月が異なっても開催月が同じ(8月)なら1件目のみ特典が適用されること" do
        travel_to(Time.zone.local(2026, 7, 11, 12, 0, 0)) do
          post public_event_join_path(another_event), params: { join_part_ids: { "0" => join_part_b.id.to_s } }
        end

        travel_to(Time.zone.local(2026, 8, 5, 12, 0, 0)) do
          post public_event_join_path(same_month_event), params: { join_part_ids: { "0" => join_part_c.id.to_s } }
        end

        first = JoinPartCustomer.find_by(customer_id: customer.id, join_part_id: join_part_b.id)
        second = JoinPartCustomer.find_by(customer_id: customer.id, join_part_id: join_part_c.id)

        expect(first.session_credit_applied?).to eq true
        expect(first.session_credit_amount).to eq 1500
        expect(second.session_credit_applied?).to eq false
        expect(second.session_credit_amount).to eq 0
      end

      it "ケース3: 開催月が同じ別イベントで特典使用済みの場合、開催月が分かる使用済み表示がされること" do
        travel_to(Time.zone.local(2026, 8, 5, 12, 0, 0)) do
          post public_event_join_path(same_month_event), params: { join_part_ids: { "0" => join_part_c.id.to_s } }
        end

        travel_to(Time.zone.local(2026, 8, 20, 12, 0, 0)) do
          get public_event_path(another_event)
        end
        expect(response.body).to include("8月分の特典は使用済み")
        expect(response.body).to include("同じ開催月の別イベントで利用済みです")

        travel_to(Time.zone.local(2026, 8, 20, 12, 0, 0)) do
          get public_event_path(same_month_event)
        end
        expect(response.body).not_to include("同じ開催月の別イベントで利用済みです")
        expect(response.body).to match(%r{当日のお支払い</span>\s*<strong>500円</strong>})
      end

      it "利用可能な場合、開催月が分かる特典対象表示がされること" do
        get public_event_path(event)

        expect(response.body).to include("7月分の特典対象")
        expect(response.body).to include("-1,500円")
      end

      it "このイベントに特典適用済みの場合、開催月が分かる適用済み表示がされること" do
        travel_to(Time.zone.local(2026, 7, 11, 12, 0, 0)) do
          post public_event_join_path(event), params: { join_part_ids: { "0" => join_part_a.id.to_s } }
        end

        get public_event_path(event)

        expect(response.body).to include("このイベントに適用済み")
        expect(response.body).to include("7月分の有料プラン特典")
      end

      it "ケース8: 開催月内のイベントをすべてキャンセルした後、同じ開催月の別イベントへ特典を再利用できること" do
        travel_to(Time.zone.local(2026, 8, 5, 12, 0, 0)) do
          post public_event_join_path(same_month_event), params: { join_part_ids: { "0" => join_part_c.id.to_s } }
        end
        expect(customer.session_credit_available_for?(event: another_event)).to eq false

        travel_to(Time.zone.local(2026, 8, 12, 12, 0, 0)) do
          delete public_event_delete_path(same_month_event, customer_id: customer.id, join_part_id: join_part_c.id)
        end
        expect(customer.session_credit_available_for?(event: another_event)).to eq true

        travel_to(Time.zone.local(2026, 8, 20, 12, 0, 0)) do
          post public_event_join_path(another_event), params: { join_part_ids: { "0" => join_part_b.id.to_s } }
        end
        credited = JoinPartCustomer.find_by(customer_id: customer.id, join_part_id: join_part_b.id)
        expect(credited.session_credit_applied?).to eq true
        expect(credited.session_credit_amount).to eq 1500
      end

      it "特典適用済みの参加を取消し、同イベントの他パートへの参加が残っていない場合は特典が消滅すること(既存仕様)" do
        travel_to(Time.zone.local(2026, 7, 11, 12, 0, 0)) do
          post public_event_join_path(event), params: { join_part_ids: { "0" => join_part_a.id.to_s } }
        end
        expect(JoinPartCustomer.where(customer_id: customer.id, session_credit_applied: true).count).to eq 1

        travel_to(Time.zone.local(2026, 7, 15, 12, 0, 0)) do
          delete public_event_delete_path(event, customer_id: customer.id, join_part_id: join_part_a.id)
        end
        expect(JoinPartCustomer.where(customer_id: customer.id, session_credit_applied: true).count).to eq 0

        expect(customer.session_credit_available_for?(event: event)).to eq true
      end

      it "特典適用済みの参加を取消しても同イベントの別パートに参加が残っている場合は特典が引き継がれること(既存仕様)" do
        second_song = FactoryBot.create(:song, event: event)
        join_part_d = FactoryBot.create(:join_part, song: second_song)

        travel_to(Time.zone.local(2026, 7, 11, 12, 0, 0)) do
          post public_event_join_path(event), params: {
            join_part_ids: { "0" => join_part_a.id.to_s, "1" => join_part_d.id.to_s }
          }
        end
        expect(JoinPartCustomer.where(customer_id: customer.id, session_credit_applied: true).count).to eq 1

        travel_to(Time.zone.local(2026, 7, 15, 12, 0, 0)) do
          delete public_event_delete_path(event, customer_id: customer.id, join_part_id: join_part_a.id)
        end

        remaining = JoinPartCustomer.find_by(customer_id: customer.id, join_part_id: join_part_d.id)
        expect(remaining.session_credit_applied?).to eq true

        expect(customer.session_credit_available_for?(event: event)).to eq false
      end

      it "有料プランユーザーがイベント詳細を表示できること" do
        get public_event_path(event)

        expect(response.status).to eq 200
      end

      it "参加確認画面を表示できること" do
        travel_to(Time.zone.local(2026, 7, 11, 12, 0, 0)) do
          get public_event_join_confirm_path(event), params: { event: { join_part_ids: [join_part_a.id.to_s] } }
        end

        expect(response.status).to eq 200
        expect(response.body).to include("参加確認画面")
        expect(response.body).to include("7月分の有料プラン特典")
      end

      it "イベント参加登録を完了できること" do
        post public_event_join_path(event), params: { join_part_ids: { "0" => join_part_a.id.to_s } }

        expect(response).to redirect_to(public_event_path(event))
        expect(JoinPartCustomer.exists?(customer_id: customer.id, join_part_id: join_part_a.id)).to eq true
      end

      it "開催月分が未使用なら1回目の申込に1,500円特典が適用され、記録として保存されること" do
        travel_to(Time.zone.local(2026, 7, 11, 12, 0, 0)) do
          post public_event_join_path(event), params: { join_part_ids: { "0" => join_part_a.id.to_s } }
        end

        credited = JoinPartCustomer.find_by(customer_id: customer.id, join_part_id: join_part_a.id)
        expect(credited.session_credit_applied?).to eq true
        expect(credited.session_credit_amount).to eq 1500
      end
    end

    context "特典適用済みイベントの料金表示(回帰テスト)" do
      let(:join_part_a) { FactoryBot.create(:join_part, song: event.songs.first) }
      let(:another_event) do
        FactoryBot.create(:event, :event_with_songs, customer: customer, community: community, entrance_fee: 2000)
      end
      let(:join_part_b) { FactoryBot.create(:join_part, song: another_event.songs.first) }

      let(:partial_fee_event) do
        FactoryBot.create(:event, :event_with_songs, customer: customer, community: community, entrance_fee: 2000)
      end
      let(:partial_fee_song2) { FactoryBot.create(:song, event: partial_fee_event) }
      let(:partial_join_part_1) { FactoryBot.create(:join_part, song: partial_fee_event.songs.first) }
      let(:partial_join_part_2) { FactoryBot.create(:join_part, song: partial_fee_song2) }
      let(:partial_join_part_3) { FactoryBot.create(:join_part, song: partial_fee_song2) }
      let(:partial_join_part_4) { FactoryBot.create(:join_part, song: partial_fee_song2) }

      it "ケース1: 参加費2,000円のイベントへ4パート同時参加し特典適用済みの場合、再表示で500円と正しく表示されること" do
        travel_to(Time.zone.local(2026, 7, 11, 17, 55, 13)) do
          post public_event_join_path(partial_fee_event), params: {
            join_part_ids: {
              "0" => partial_join_part_1.id.to_s,
              "1" => partial_join_part_2.id.to_s,
              "2" => partial_join_part_3.id.to_s,
              "3" => partial_join_part_4.id.to_s
            }
          }
        end
        expect(JoinPartCustomer.where(customer_id: customer.id, session_credit_applied: true).count).to eq 1

        get public_event_path(partial_fee_event)

        expect(response.body).to include("-1,500円")
        expect(response.body).to match(%r{当日のお支払い</span>\s*<strong>500円</strong>})
        expect(response.body).not_to include("同じ開催月の別イベントで利用済みです")
      end

      it "ケース2: 特典適用済みレコードが取得順序上2件目以降でも、イベント単位で正しく1,500円/500円を表示すること" do
        first_record = JoinPartCustomer.create!(
          customer: customer, join_part: partial_join_part_1,
          session_credit_applied: false, session_credit_amount: 0
        )
        second_record = JoinPartCustomer.create!(
          customer: customer, join_part: partial_join_part_2,
          session_credit_applied: true, session_credit_amount: 1500, plan_snapshot: "core"
        )
        expect(first_record.id).to be < second_record.id

        get public_event_path(partial_fee_event)

        expect(response.body).to include("-1,500円")
        expect(response.body).to match(%r{当日のお支払い</span>\s*<strong>500円</strong>})
        expect(response.body).not_to include("同じ開催月の別イベントで利用済みです")
      end

      it "ケース3: 別イベントで特典を使用済みの場合、そのイベント自身では「同じ開催月の別イベントで利用済み」と表示されないこと" do
        travel_to(Time.zone.local(2026, 7, 3, 12, 0, 0)) do
          post public_event_join_path(event), params: { join_part_ids: { "0" => join_part_a.id.to_s } }
        end

        travel_to(Time.zone.local(2026, 7, 20, 12, 0, 0)) do
          get public_event_path(another_event)
        end
        expect(response.body).to include("9月分の特典は使用済み")
        expect(response.body).to include("同じ開催月の別イベントで利用済みです")

        travel_to(Time.zone.local(2026, 7, 20, 12, 0, 0)) do
          get public_event_path(event)
        end
        expect(response.body).not_to include("同じ開催月の別イベントで利用済みです")
        expect(response.body).to match(%r{当日のお支払い</span>\s*<strong>0円</strong>})
      end

      it "ケース5: 残額500円がある場合、参加者一覧に「集金不要」と表示されないこと" do
        travel_to(Time.zone.local(2026, 7, 3, 12, 0, 0)) do
          post public_event_join_path(another_event), params: { join_part_ids: { "0" => join_part_b.id.to_s } }
        end

        get public_event_path(another_event)

        expect(response.body).not_to include("集金不要")
        expect(response.body).to include("当日集金")
        expect(response.body).to include("500円")
      end

      it "ケース6: 残額0円の場合、参加者一覧に「集金不要」と表示されること" do
        travel_to(Time.zone.local(2026, 7, 3, 12, 0, 0)) do
          post public_event_join_path(event), params: { join_part_ids: { "0" => join_part_a.id.to_s } }
        end

        get public_event_path(event)

        expect(response.body).to include("集金不要")
      end

      it "ケース7: 同一イベントへの追加パート登録確認画面では「別イベントで利用済み」と表示されず、適用済みと分かる表示になること" do
        extra_join_part = FactoryBot.create(:join_part, song: partial_fee_song2)

        travel_to(Time.zone.local(2026, 7, 3, 12, 0, 0)) do
          post public_event_join_path(partial_fee_event), params: { join_part_ids: { "0" => partial_join_part_1.id.to_s } }
        end

        travel_to(Time.zone.local(2026, 7, 5, 12, 0, 0)) do
          get public_event_join_confirm_path(partial_fee_event), params: { event: { join_part_ids: [extra_join_part.id.to_s] } }
        end

        expect(response.body).to include("特典が適用済み")
        expect(response.body).not_to include("同じ開催月の別イベントで利用済みです")
        expect(response.body).to match(%r{当日のお支払い</span>\s*<strong>500円</strong>})
      end

      it "ケース8: CSV出力の集金不要判定がイベント詳細画面の残額判定と一致すること" do
        csv_join_part = FactoryBot.create(:join_part, song: another_event.songs.first, join_part_name: "Vocal")

        travel_to(Time.zone.local(2026, 7, 3, 12, 0, 0)) do
          post public_event_join_path(another_event), params: { join_part_ids: { "0" => csv_join_part.id.to_s } }
        end

        get public_event_path(another_event, format: :csv)

        expect(response.status).to eq 200
        expect(response.body).to include("特典適用")
        expect(response.body).not_to include("集金不要")
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
