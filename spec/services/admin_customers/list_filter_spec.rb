require "rails_helper"

RSpec.describe AdminCustomers::ListFilter do
  # アプリのタイムゾーン(Tokyo)で、月末の翌月にまたがる日時を基準にする。
  let(:now) { Time.zone.local(2026, 3, 31, 12, 0, 0) }

  def ids_for(params)
    described_class.call(Customer.all, ActionController::Parameters.new(params), now: now).pluck(:id)
  end

  describe "最終ログイン" do
    let!(:exactly_one_day) { FactoryBot.create(:customer, current_sign_in_at: now - 1.day) }
    let!(:just_over_one_day) { FactoryBot.create(:customer, current_sign_in_at: now - 1.day - 1.second) }
    let!(:exactly_three_days) { FactoryBot.create(:customer, current_sign_in_at: now - 3.days) }
    let!(:just_over_three_days) { FactoryBot.create(:customer, current_sign_in_at: now - 3.days - 1.second) }
    # 暦上の1ヶ月: 3/31 の1ヶ月前は 2/28(2026年は平年)
    let!(:calendar_month_boundary) { FactoryBot.create(:customer, current_sign_in_at: Time.zone.local(2026, 2, 28, 12, 0, 0)) }
    let!(:before_calendar_month) { FactoryBot.create(:customer, current_sign_in_at: Time.zone.local(2026, 2, 28, 11, 59, 59)) }
    let!(:never_signed_in) { FactoryBot.create(:customer, current_sign_in_at: nil) }

    it "1日以内は、ちょうど24時間前を含み、それより前を含まない" do
      expect(ids_for(last_login: "1d")).to contain_exactly(exactly_one_day.id)
    end

    it "3日以内は、ちょうど3日前を含み、それより前を含まない" do
      expect(ids_for(last_login: "3d")).to contain_exactly(exactly_one_day.id, just_over_one_day.id, exactly_three_days.id)
    end

    it "1ヶ月以内は暦上の1ヶ月(3/31 → 2/28)で区切る" do
      ids = ids_for(last_login: "1m")
      expect(ids).to include(calendar_month_boundary.id, just_over_three_days.id)
      expect(ids).not_to include(before_calendar_month.id)
    end

    it "ログイン履歴のない人は期間指定の対象外で、「すべて」なら含まれる" do
      %w[1d 3d 1m].each { |period| expect(ids_for(last_login: period)).not_to include(never_signed_in.id) }
      expect(ids_for(last_login: "")).to include(never_signed_in.id)
    end

    it "タイムゾーンは Tokyo で、UTC の値として比較しても同じ境界になる" do
      expect(described_class.call(Customer.all, { last_login: "1d" }, now: now.utc).pluck(:id)).to contain_exactly(exactly_one_day.id)
    end
  end

  describe "メール承認" do
    let!(:confirmed) { FactoryBot.create(:customer, confirmed_at: now - 10.days) }
    let!(:unconfirmed) { FactoryBot.create(:customer).tap { |customer| customer.update_column(:confirmed_at, nil) } }

    it "承認済み・未承認・すべてで絞り込める" do
      expect(ids_for(email_confirmation: "confirmed")).to include(confirmed.id)
      expect(ids_for(email_confirmation: "confirmed")).not_to include(unconfirmed.id)
      expect(ids_for(email_confirmation: "unconfirmed")).to contain_exactly(unconfirmed.id)
      expect(ids_for(email_confirmation: "")).to include(confirmed.id, unconfirmed.id)
    end
  end

  describe "組み合わせ" do
    let!(:recent_confirmed) { FactoryBot.create(:customer, current_sign_in_at: now - 2.hours) }
    let!(:recent_unconfirmed) do
      FactoryBot.create(:customer, current_sign_in_at: now - 2.hours).tap { |customer| customer.update_column(:confirmed_at, nil) }
    end
    let!(:old_unconfirmed) do
      FactoryBot.create(:customer, current_sign_in_at: now - 10.days).tap { |customer| customer.update_column(:confirmed_at, nil) }
    end

    it "最終ログインとメール承認を同時に指定すると、両方を満たす人だけになる" do
      expect(ids_for(last_login: "1d", email_confirmation: "unconfirmed")).to contain_exactly(recent_unconfirmed.id)
      expect(ids_for(last_login: "1d", email_confirmation: "confirmed")).to contain_exactly(recent_confirmed.id)
      expect(ids_for(last_login: "1m", email_confirmation: "unconfirmed")).to contain_exactly(recent_unconfirmed.id, old_unconfirmed.id)
    end

    it "既存のプロフィール絞り込みとも組み合わせられる" do
      MemberProfile.create!(customer: recent_unconfirmed, suggested_member_type: MemberProfile.suggested_member_types.keys.first)

      ids = ids_for(last_login: "1d", email_confirmation: "unconfirmed", member_type: MemberProfile.suggested_member_types.keys.first)
      expect(ids).to contain_exactly(recent_unconfirmed.id)
      expect(ids_for(last_login: "1d", member_type: MemberProfile.suggested_member_types.keys.first)).to contain_exactly(recent_unconfirmed.id)
    end

    it "想定外の値は無視する" do
      expect(ids_for(last_login: "7y", email_confirmation: "maybe")).to include(recent_confirmed.id, recent_unconfirmed.id, old_unconfirmed.id)
    end
  end
end
