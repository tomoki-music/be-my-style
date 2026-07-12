require "rails_helper"

RSpec.describe "Customerの有料プラン月次特典(session_credit)判定 - イベント開催月基準", type: :model do
  include ActiveSupport::Testing::TimeHelpers

  let(:customer) { FactoryBot.create(:customer) }

  def create_event(start_time:, entrance_fee: 2000)
    FactoryBot.create(
      :event, :event_with_songs, entrance_fee: entrance_fee,
      event_start_time: start_time,
      event_end_time: start_time + 2.hours,
      event_entry_deadline: start_time - 5.days
    )
  end

  def create_credited_participation!(event:, applied_at:)
    join_part = FactoryBot.create(:join_part, song: event.songs.first)

    travel_to(applied_at) do
      JoinPartCustomer.create!(
        customer: customer,
        join_part: join_part,
        session_credit_applied: true,
        session_credit_amount: Customer::MONTHLY_SESSION_CREDIT_AMOUNT,
        plan_snapshot: customer.plan
      )
    end
  end

  context "有料プラン契約中の場合" do
    before { customer.create_subscription!(status: "active", plan: "core") }

    it "ケース1: 開催月(7月)のイベントで特典を使っていても、開催月が異なる(8月)別イベントには特典を適用できる(申込月が同じでも)" do
      event_july = create_event(start_time: Time.zone.local(2026, 7, 25, 19, 0, 0))
      event_august = create_event(start_time: Time.zone.local(2026, 8, 22, 19, 0, 0))

      create_credited_participation!(event: event_july, applied_at: Time.zone.local(2026, 7, 11, 12, 0, 0))

      expect(customer.session_credit_available_for?(event: event_august)).to eq true
      expect(customer.session_credit_amount_for(event_august)).to eq 1500
    end

    it "ケース2: 開催月が同じ(8月)なら、申込月が異なっていても別イベントで既に利用済みなら利用不可になる" do
      event_a = create_event(start_time: Time.zone.local(2026, 8, 10, 19, 0, 0))
      event_b = create_event(start_time: Time.zone.local(2026, 8, 22, 19, 0, 0))

      create_credited_participation!(event: event_a, applied_at: Time.zone.local(2026, 7, 11, 12, 0, 0))

      travel_to(Time.zone.local(2026, 8, 1, 12, 0, 0)) do
        expect(customer.session_credit_available_for?(event: event_b)).to eq false
        expect(customer.session_credit_amount_for(event_b)).to eq 0
      end
    end

    it "ケース4: 開催月が異なれば(7/31開催と8/1開催)月末月初をまたいでもそれぞれ特典が適用されること" do
      event_a = create_event(start_time: Time.zone.local(2026, 7, 31, 23, 0, 0))
      event_b = create_event(start_time: Time.zone.local(2026, 8, 1, 1, 0, 0))

      create_credited_participation!(event: event_a, applied_at: Time.zone.local(2026, 7, 20, 12, 0, 0))

      expect(customer.session_credit_available_for?(event: event_b)).to eq true
    end

    it "ケース5: 年をまたいでも(12月開催→翌1月開催)それぞれ特典が適用されること" do
      event_dec = create_event(start_time: Time.zone.local(2026, 12, 20, 19, 0, 0))
      event_jan = create_event(start_time: Time.zone.local(2027, 1, 5, 19, 0, 0))

      create_credited_participation!(event: event_dec, applied_at: Time.zone.local(2026, 12, 10, 12, 0, 0))

      expect(customer.session_credit_available_for?(event: event_jan)).to eq true
    end

    it "ケース6: 前年同月(2025年8月開催)に利用済みでも2026年8月開催イベントは利用可能になる" do
      old_event = create_event(start_time: Time.zone.local(2025, 8, 15, 19, 0, 0))
      new_event = create_event(start_time: Time.zone.local(2026, 8, 15, 19, 0, 0))

      create_credited_participation!(event: old_event, applied_at: Time.zone.local(2025, 8, 1, 12, 0, 0))

      expect(customer.session_credit_available_for?(event: new_event)).to eq true
    end

    it "利用履歴が一度もなければ対象イベントの開催月分を利用できる" do
      event = create_event(start_time: Time.zone.local(2026, 7, 25, 19, 0, 0))

      expect(customer.session_credit_available_for?(event: event)).to eq true
    end

    it "参加費が1,500円未満の場合は参加費と同額のみ適用される" do
      cheap_event = create_event(start_time: Time.zone.local(2026, 7, 25, 19, 0, 0), entrance_fee: 1000)

      expect(customer.session_credit_amount_for(cheap_event)).to eq 1000
    end

    it "参加費が1,500円以上の場合は1,500円が適用される" do
      event = create_event(start_time: Time.zone.local(2026, 7, 25, 19, 0, 0), entrance_fee: 2000)

      expect(customer.session_credit_amount_for(event)).to eq 1500
    end
  end

  context "無料プランの場合" do
    it "利用履歴にかかわらず特典対象外になる" do
      event = create_event(start_time: Time.zone.local(2026, 7, 25, 19, 0, 0))

      expect(customer.session_credit_available_for?(event: event)).to eq false
      expect(customer.session_credit_amount_for(event)).to eq 0
    end
  end
end
