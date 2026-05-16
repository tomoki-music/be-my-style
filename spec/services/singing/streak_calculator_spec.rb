require "rails_helper"

RSpec.describe Singing::StreakCalculator do
  let(:customer) { create(:customer, domain_name: "singing") }

  def completed_on(date)
    create(:singing_diagnosis, :completed, customer: customer,
           created_at: date.to_time.in_time_zone)
  end

  describe ".call" do
    context "診断が1件もない場合" do
      it "0を返すこと" do
        expect(described_class.call(customer)).to eq 0
      end
    end

    context "今日だけ診断した場合" do
      it "1を返すこと" do
        completed_on(Time.zone.today)
        expect(described_class.call(customer)).to eq 1
      end
    end

    context "昨日と今日連続した場合" do
      it "2を返すこと" do
        completed_on(1.day.ago.to_date)
        completed_on(Time.zone.today)
        expect(described_class.call(customer)).to eq 2
      end
    end

    context "3日連続した場合" do
      it "3を返すこと" do
        completed_on(2.days.ago.to_date)
        completed_on(1.day.ago.to_date)
        completed_on(Time.zone.today)
        expect(described_class.call(customer)).to eq 3
      end
    end

    context "途中で1日抜けた場合" do
      it "抜けた後からのstreakを返すこと（今日のみ）" do
        completed_on(3.days.ago.to_date)
        completed_on(2.days.ago.to_date)
        # 昨日（1日前）が抜けている → 今日のみ streak
        completed_on(Time.zone.today)
        expect(described_class.call(customer)).to eq 1
      end
    end

    context "昨日だけで今日は診断していない場合" do
      it "0を返すこと（Today基準）" do
        completed_on(1.day.ago.to_date)
        expect(described_class.call(customer)).to eq 0
      end
    end

    context "同じ日に複数回診断した場合" do
      it "重複をカウントせず1として扱うこと" do
        today = Time.zone.today
        completed_on(today)
        completed_on(today) # 同日2回目
        expect(described_class.call(customer)).to eq 1
      end
    end

    context "as_of_date を指定した場合" do
      it "指定日を基準にstreakを計算すること" do
        base = Date.new(2026, 5, 10)
        completed_on(base - 2.days)
        completed_on(base - 1.day)
        completed_on(base)
        expect(described_class.call(customer, as_of_date: base)).to eq 3
      end
    end

    context "他ユーザーの診断がある場合" do
      it "他ユーザーの診断は計算に含まれないこと" do
        other = create(:customer, domain_name: "singing")
        create(:singing_diagnosis, :completed, customer: other, created_at: Time.zone.today)
        expect(described_class.call(customer)).to eq 0
      end
    end
  end
end
