require "rails_helper"

RSpec.describe "Customerの有料プラン月次特典(session_credit)判定", type: :model do
  include ActiveSupport::Testing::TimeHelpers

  let(:customer) { FactoryBot.create(:customer) }
  let(:event) { FactoryBot.create(:event, :event_with_songs, entrance_fee: 2000) }
  let(:credit_source_event) { FactoryBot.create(:event, :event_with_songs) }

  def create_credited_participation!(at:)
    song = FactoryBot.create(:song, event: credit_source_event)
    join_part = FactoryBot.create(:join_part, song: song)

    travel_to(at) do
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

    it "ケース1: 先月(6月)利用済みでも今月(7月)はまだ未利用として1,500円が利用可能になる" do
      create_credited_participation!(at: Time.zone.local(2026, 6, 15, 12, 0, 0))

      travel_to(Time.zone.local(2026, 7, 10, 12, 0, 0)) do
        expect(customer.session_credit_available_for?).to eq true
        expect(customer.session_credit_amount_for(event)).to eq 1500
      end
    end

    it "ケース2: 今月(7月)すでに利用済みなら同月内の次回申込では利用不可になる" do
      create_credited_participation!(at: Time.zone.local(2026, 7, 3, 12, 0, 0))

      travel_to(Time.zone.local(2026, 7, 20, 12, 0, 0)) do
        expect(customer.session_credit_available_for?).to eq false
        expect(customer.session_credit_amount_for(event)).to eq 0
      end
    end

    it "ケース3: 利用履歴が一度もなければ今月分を利用できる" do
      travel_to(Time.zone.local(2026, 7, 20, 12, 0, 0)) do
        expect(customer.session_credit_available_for?).to eq true
      end
    end

    it "ケース5: 7月に利用済みでも8月になれば再び利用可能になる" do
      create_credited_participation!(at: Time.zone.local(2026, 7, 3, 12, 0, 0))

      travel_to(Time.zone.local(2026, 8, 1, 0, 0, 1)) do
        expect(customer.session_credit_available_for?).to eq true
      end
    end

    it "ケース6: 12月に利用済みでも年をまたいだ1月は利用可能になる" do
      create_credited_participation!(at: Time.zone.local(2026, 12, 20, 12, 0, 0))

      travel_to(Time.zone.local(2027, 1, 5, 12, 0, 0)) do
        expect(customer.session_credit_available_for?).to eq true
      end
    end

    it "ケース7: 前年同月(2025年7月)に利用済みでも年を無視せず2026年7月は利用可能になる" do
      create_credited_participation!(at: Time.zone.local(2025, 7, 15, 12, 0, 0))

      travel_to(Time.zone.local(2026, 7, 15, 12, 0, 0)) do
        expect(customer.session_credit_available_for?).to eq true
      end
    end

    it "ケース8: 月末23:59台と翌月0:00台の境界(JST基準)で正しい月にカウントされる" do
      create_credited_participation!(at: Time.zone.local(2026, 6, 30, 23, 59, 59))

      travel_to(Time.zone.local(2026, 6, 30, 23, 59, 59)) do
        expect(customer.session_credit_available_for?).to eq false
      end

      travel_to(Time.zone.local(2026, 7, 1, 0, 0, 1)) do
        expect(customer.session_credit_available_for?).to eq true
      end
    end

    it "回帰: 開催月が同じ(8月)別イベントでも、6月に使った特典で7月分が誤って使用済みにならない" do
      event_a = FactoryBot.create(
        :event, :event_with_songs, entrance_fee: 2000,
        event_start_time: Time.zone.local(2026, 8, 15, 19, 0, 0),
        event_end_time: Time.zone.local(2026, 8, 15, 21, 0, 0),
        event_entry_deadline: Time.zone.local(2026, 8, 10, 0, 0, 0)
      )
      join_part_a = FactoryBot.create(:join_part, song: event_a.songs.first)

      travel_to(Time.zone.local(2026, 6, 10, 12, 0, 0)) do
        jpc = JoinPartCustomer.create!(customer: customer, join_part: join_part_a)
        jpc.update!(session_credit_applied: true, session_credit_amount: 1500, plan_snapshot: customer.plan)
      end

      event_b = FactoryBot.create(
        :event, :event_with_songs, entrance_fee: 2000,
        event_start_time: Time.zone.local(2026, 8, 20, 19, 0, 0),
        event_end_time: Time.zone.local(2026, 8, 20, 21, 0, 0),
        event_entry_deadline: Time.zone.local(2026, 8, 15, 0, 0, 0)
      )

      travel_to(Time.zone.local(2026, 7, 5, 12, 0, 0)) do
        expect(customer.session_credit_available_for?).to eq true
        expect(customer.session_credit_amount_for(event_b)).to eq 1500
      end
    end

    it "ケース10: 参加費が1,500円未満の場合は参加費と同額のみ適用される" do
      cheap_event = FactoryBot.create(:event, :event_with_songs, entrance_fee: 1000)

      travel_to(Time.zone.local(2026, 7, 20, 12, 0, 0)) do
        expect(customer.session_credit_amount_for(cheap_event)).to eq 1000
      end
    end
  end

  context "無料プランの場合" do
    it "ケース4: 利用履歴にかかわらず特典対象外になる" do
      travel_to(Time.zone.local(2026, 7, 20, 12, 0, 0)) do
        expect(customer.session_credit_available_for?).to eq false
        expect(customer.session_credit_amount_for(event)).to eq 0
      end
    end
  end
end
