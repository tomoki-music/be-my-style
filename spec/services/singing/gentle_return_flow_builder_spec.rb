require "rails_helper"

RSpec.describe Singing::GentleReturnFlowBuilder do
  include ActiveSupport::Testing::TimeHelpers

  describe ".call" do
    let(:customer) { create(:customer, domain_name: "singing") }
    let(:now) { Time.zone.local(2026, 6, 3, 12, 0, 0) }

    around do |example|
      travel_to(now) { example.run }
    end

    it "nil customerでは表示しない" do
      result = described_class.call(nil)

      expect(result).to be_a(described_class::Result)
      expect(result.active?).to eq(false)
      expect(result.absence_level).to eq(:none)
      expect(result.cta_path).to be_nil
    end

    it "活動がなければ新規ユーザー向けに表示しない" do
      result = described_class.call(customer)

      expect(result.active?).to eq(false)
      expect(result.absence_level).to eq(:none)
      expect(result.latest_activity_at).to be_nil
      expect(result.activity_source).to be_nil
    end

    it "7日未満の活動では表示しない" do
      diagnosis = create(:singing_diagnosis, :completed, customer: customer, created_at: 6.days.ago)

      result = described_class.call(customer)

      expect(result.active?).to eq(false)
      expect(result.absence_level).to eq(:none)
      expect(result.latest_activity_at).to be_within(1.second).of(diagnosis.created_at)
      expect(result.activity_source).to eq(:diagnosis)
    end

    it "7日前の活動では medium_absence を表示する" do
      diagnosis = create(:singing_diagnosis, :completed, customer: customer, created_at: 7.days.ago)

      result = described_class.call(customer)

      expect(result.active?).to eq(true)
      expect(result.icon).to eq("🎵")
      expect(result.title).to eq("また少しずつ始めましょう")
      expect(result.message).to eq("前の続きからで大丈夫です。\n今日できる小さな一歩を選びましょう。")
      expect(result.cta_label).to eq("今日の一歩を見る")
      expect(result.cta_path).to eq("#todays-mission")
      expect(result.absence_level).to eq(:medium_absence)
      expect(result.latest_activity_at).to be_within(1.second).of(diagnosis.created_at)
      expect(result.activity_source).to eq(:diagnosis)
    end

    it "29日前の活動では medium_absence を表示する" do
      diagnosis = create(:singing_diagnosis, :completed, customer: customer, created_at: 29.days.ago)

      result = described_class.call(customer)

      expect(result.active?).to eq(true)
      expect(result.absence_level).to eq(:medium_absence)
      expect(result.latest_activity_at).to be_within(1.second).of(diagnosis.created_at)
    end

    it "30日前の活動では long_absence を表示する" do
      diagnosis = create(:singing_diagnosis, :completed, customer: customer, created_at: 30.days.ago)

      result = described_class.call(customer)

      expect(result.active?).to eq(true)
      expect(result.icon).to eq("🌙")
      expect(result.title).to eq("おかえりなさい")
      expect(result.message).to eq("少し間が空いても大丈夫です。\n音楽は、また今日から楽しめます。")
      expect(result.cta_label).to eq("軽く歌ってみる")
      expect(result.cta_path).to eq(Rails.application.routes.url_helpers.new_singing_diagnosis_path)
      expect(result.absence_level).to eq(:long_absence)
      expect(result.latest_activity_at).to be_within(1.second).of(diagnosis.created_at)
      expect(result.activity_source).to eq(:diagnosis)
    end

    it "completed diagnosis を活動として扱う" do
      create(:singing_diagnosis, :completed, customer: customer, created_at: 8.days.ago)

      result = described_class.call(customer)

      expect(result.active?).to eq(true)
      expect(result.activity_source).to eq(:diagnosis)
      expect(result.absence_level).to eq(:medium_absence)
    end

    it "未完了 diagnosis は活動として扱わない" do
      create(:singing_diagnosis, customer: customer, created_at: 8.days.ago)

      result = described_class.call(customer)

      expect(result.active?).to eq(false)
      expect(result.activity_source).to be_nil
    end

    it "reaction sent を活動として扱う" do
      reaction = create(:singing_profile_reaction, customer: customer, created_at: 8.days.ago)

      result = described_class.call(customer)

      expect(result.active?).to eq(true)
      expect(result.activity_source).to eq(:reaction_sent)
      expect(result.latest_activity_at).to be_within(1.second).of(reaction.created_at)
    end

    it "reaction received を活動として扱う" do
      sender = create(:customer, domain_name: "singing")
      reaction = create(:singing_profile_reaction, customer: sender, target_customer: customer, created_at: 8.days.ago)

      result = described_class.call(customer)

      expect(result.active?).to eq(true)
      expect(result.activity_source).to eq(:reaction_received)
      expect(result.latest_activity_at).to be_within(1.second).of(reaction.created_at)
    end

    it "challenge progress を活動として扱う" do
      progress = create(:singing_ai_challenge_progress, customer: customer, updated_at: 8.days.ago)

      result = described_class.call(customer)

      expect(result.active?).to eq(true)
      expect(result.activity_source).to eq(:challenge_progress)
      expect(result.latest_activity_at).to be_within(1.second).of(progress.updated_at)
    end

    it "複数活動がある場合は最新活動で判定する" do
      create(:singing_diagnosis, :completed, customer: customer, created_at: 30.days.ago)
      reaction = create(:singing_profile_reaction, customer: customer, created_at: 6.days.ago)

      result = described_class.call(customer)

      expect(result.active?).to eq(false)
      expect(result.absence_level).to eq(:none)
      expect(result.latest_activity_at).to be_within(1.second).of(reaction.created_at)
      expect(result.activity_source).to eq(:reaction_sent)
    end
  end
end
