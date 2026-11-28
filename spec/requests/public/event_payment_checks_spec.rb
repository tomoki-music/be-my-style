require "rails_helper"

RSpec.describe "イベントの集金チェック票", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:community) { FactoryBot.create(:community) }
  let(:creator) { FactoryBot.create(:customer, name: "イベント作成者") }
  let(:community_owner) { FactoryBot.create(:customer, name: "主催オーナー") }
  let(:co_owner) { FactoryBot.create(:customer, name: "共同オーナー") }
  let(:manager) { FactoryBot.create(:customer, name: "マネージャー", is_owner: :manager) }
  let(:admin) { FactoryBot.create(:customer, name: "システム管理者", is_owner: :admin) }
  let(:member) { FactoryBot.create(:customer, name: "一般メンバー") }
  let(:vocal) { FactoryBot.create(:customer, name: "ボーカル会員") }
  let(:guitar) { FactoryBot.create(:customer, name: "ギター会員") }
  let(:event) { FactoryBot.create(:event, :event_with_songs, community: community, customer: creator, entrance_fee: 1500) }
  let!(:second_song) { FactoryBot.create(:song, event: event, song_name: "2曲目", position: 2) }

  before do
    community.update!(owner_id: community_owner.id)
    CommunityOwner.create!(community: community, customer: co_owner)
    CommunityEventEditor.create!(community: community, customer: manager)
    [creator, member, vocal, guitar, manager].each do |customer|
      CommunityCustomer.find_or_create_by!(customer: customer, community: community)
    end

    first_song = event.songs.first
    JoinPartCustomer.create!(join_part: FactoryBot.create(:join_part, song: first_song, join_part_name: "Vocal"), customer: vocal)
    JoinPartCustomer.create!(join_part: FactoryBot.create(:join_part, song: first_song, join_part_name: "Guitar"), customer: guitar)
    # 同じ会員が2曲目にも出る
    JoinPartCustomer.create!(join_part: FactoryBot.create(:join_part, song: second_song, join_part_name: "Cho"), customer: vocal)
  end

  def rows
    Nokogiri::HTML(response.body).css(".payment-checklist__row")
  end

  describe "閲覧" do
    it "主催オーナー・CommunityOwner・システム管理者は開ける" do
      [community_owner, co_owner, admin].each do |customer|
        sign_in customer
        get public_event_payment_checks_path(event)
        expect(response).to have_http_status(:ok), "#{customer.name} が開けない"
        sign_out customer
      end
    end

    it "イベント作成者・マネージャー・一般メンバーは直接アクセスしても開けない" do
      [creator, manager, member].each do |customer|
        sign_in customer
        get public_event_payment_checks_path(event)
        expect(response).to redirect_to(public_event_path(event)), "#{customer.name} が開けてしまう"
        sign_out customer
      end
    end

    it "複数曲に出る人も1人1行で、集金済み人数/対象人数を表示する" do
      sign_in community_owner
      get public_event_payment_checks_path(event)

      expect(rows.map { |row| row.at_css(".payment-checklist__name").text }).to eq %w[ボーカル会員 ギター会員]
      expect(response.body).to include("集金済み")
      expect(Nokogiri::HTML(response.body).at_css(".payment-checklist__summary").text.gsub(/\s+/, "")).to eq "集金済み0/2人"
    end
  end

  describe "イベント詳細の入口ボタン" do
    it "権限のある人にだけ表示する" do
      sign_in community_owner
      get public_event_path(event)
      expect(response.body).to include(public_event_payment_checks_path(event))
      sign_out community_owner

      [creator, manager, member].each do |customer|
        sign_in customer
        get public_event_path(event)
        expect(response.body).not_to include(public_event_payment_checks_path(event)), "#{customer.name} に表示されている"
        sign_out customer
      end
    end
  end

  describe "更新" do
    it "集金済みにして、最後に変更した人と日時を記録し、取消もできる" do
      sign_in community_owner
      travel_to Time.zone.local(2030, 1, 12, 18, 5) do
        patch public_event_payment_check_path(event, vocal.id), params: { collected: "1" }
      end
      expect(response).to redirect_to(public_event_payment_checks_path(event, anchor: "payment-check-#{vocal.id}"))

      check = EventPaymentCheck.find_by!(event: event, customer: vocal)
      expect(check.collected).to be true
      expect(check.updated_by).to eq community_owner
      expect(check.updated_at).to eq Time.zone.local(2030, 1, 12, 18, 5)

      get public_event_payment_checks_path(event)
      expect(Nokogiri::HTML(response.body).at_css(".payment-checklist__summary").text.gsub(/\s+/, "")).to eq "集金済み1/2人"
      expect(response.body).to include("最終更新: 主催オーナー（1/12 18:05）")
      sign_out community_owner

      sign_in admin
      patch public_event_payment_check_path(event, vocal.id), params: { collected: "0" }
      check.reload
      expect(check.collected).to be false
      expect(check.updated_by).to eq admin
      expect(EventPaymentCheck.where(event: event, customer: vocal).count).to eq 1
    end

    describe "参加費の表示と合計" do
      let(:partial) { FactoryBot.create(:customer, name: "一部特典会員") }
      let(:free) { FactoryBot.create(:customer, name: "全額特典会員") }

      before do
        [partial, free].each { |customer| CommunityCustomer.find_or_create_by!(customer: customer, community: community) }
        song = event.songs.first
        JoinPartCustomer.create!(join_part: FactoryBot.create(:join_part, song: song, join_part_name: "Bass"), customer: partial,
                                 session_credit_applied: true, session_credit_amount: 500)
        JoinPartCustomer.create!(join_part: FactoryBot.create(:join_part, song: song, join_part_name: "Drums"), customer: free,
                                 session_credit_applied: true, session_credit_amount: 1500)
      end

      def fee_of(customer)
        Nokogiri::HTML(response.body).at_css("#payment-check-#{customer.id} .payment-checklist__fee").text.strip
      end

      def totals
        doc = Nokogiri::HTML(response.body)
        %w[expected collected uncollected].map { |key| doc.at_css(".payment-checklist__total-#{key}").text.strip }
      end

      def summary
        Nokogiri::HTML(response.body).at_css(".payment-checklist__summary").text.gsub(/\s+/, "")
      end

      it "人ごとの参加費(0円は集金不要)と、保存・取消に合わせた人数・合計を表示する" do
        sign_in community_owner
        get public_event_payment_checks_path(event)

        expect(fee_of(vocal)).to eq "参加費 1,500円"
        expect(fee_of(partial)).to eq "参加費 1,000円"
        expect(fee_of(free)).to eq "集金不要"
        expect(summary).to eq "集金済み0/4人"
        expect(totals).to eq ["4,000円", "0円", "4,000円"]
        expect(response.body).to include("実際に受け取った金額の記録ではなく")

        patch public_event_payment_check_path(event, partial.id), params: { collected: "1" }
        patch public_event_payment_check_path(event, vocal.id), params: { collected: "1" }
        get public_event_payment_checks_path(event)
        expect(summary).to eq "集金済み2/4人"
        expect(totals).to eq ["4,000円", "2,500円", "1,500円"]

        # 集金不要の人も対象人数に含まれ、チェックすると人数だけ増える(金額は0円)
        patch public_event_payment_check_path(event, free.id), params: { collected: "1" }
        patch public_event_payment_check_path(event, vocal.id), params: { collected: "0" }
        get public_event_payment_checks_path(event)
        expect(summary).to eq "集金済み2/4人"
        expect(totals).to eq ["4,000円", "1,000円", "3,000円"]
      end

      it "参加費を変えると表示額も今の設定で計算し直す(記録した金額ではない)" do
        sign_in community_owner
        patch public_event_payment_check_path(event, vocal.id), params: { collected: "1" }
        event.update_column(:entrance_fee, 2000)

        get public_event_payment_checks_path(event)
        expect(fee_of(vocal)).to eq "参加費 2,000円"
        expect(fee_of(free)).to eq "参加費 500円"
        expect(totals).to eq ["6,000円", "2,000円", "4,000円"]
      end
    end

    it "チェックしてもエントリー・参加人数・参加費は変わらない" do
      sign_in community_owner
      expect do
        patch public_event_payment_check_path(event, vocal.id), params: { collected: "1" }
      end.not_to(change { [JoinPartCustomer.count, event.reload.entrance_fee, event.join_members.size] })
    end

    it "権限のない人は更新できない" do
      [creator, manager, member].each do |customer|
        sign_in customer
        patch public_event_payment_check_path(event, vocal.id), params: { collected: "1" }
        expect(response).to redirect_to(public_event_path(event))
        sign_out customer
      end
      expect(EventPaymentCheck.count).to eq 0
    end

    it "他イベントの参加者や参加していない会員は、このイベントのURLから更新できない" do
      other_event = FactoryBot.create(:event, :event_with_songs, community: community, customer: creator)
      other_member = FactoryBot.create(:customer, name: "他イベント参加者")
      JoinPartCustomer.create!(join_part: FactoryBot.create(:join_part, song: other_event.songs.first, join_part_name: "Bass"), customer: other_member)

      sign_in community_owner
      patch public_event_payment_check_path(event, other_member.id), params: { collected: "1" }
      expect(response).to redirect_to(public_event_payment_checks_path(event))
      patch public_event_payment_check_path(event, member.id), params: { collected: "1" }
      expect(response).to redirect_to(public_event_payment_checks_path(event))
      expect(EventPaymentCheck.count).to eq 0
    end

    it "他コミュニティ主催イベントのオーナーではない人は、そのイベントを更新できない" do
      other_community = FactoryBot.create(:community)
      other_event = FactoryBot.create(:event, :event_with_songs, community: other_community, customer: creator)
      JoinPartCustomer.create!(join_part: FactoryBot.create(:join_part, song: other_event.songs.first, join_part_name: "Bass"), customer: vocal)

      sign_in community_owner
      patch public_event_payment_check_path(other_event, vocal.id), params: { collected: "1" }
      expect(response).to redirect_to(public_event_path(other_event))
      expect(EventPaymentCheck.count).to eq 0
    end
  end
end
