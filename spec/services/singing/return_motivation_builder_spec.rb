require "rails_helper"

RSpec.describe Singing::ReturnMotivationBuilder do
  include ActiveSupport::Testing::TimeHelpers

  describe ".call" do
    let(:customer) { create(:customer, domain_name: "singing") }
    let(:now) { Time.zone.local(2026, 6, 3, 12, 0, 0) }

    around do |example|
      travel_to(now) { example.run }
    end

    it "customer nilでは表示しない" do
      result = described_class.call(nil)

      expect(result).to be_a(described_class::ReturnMotivation)
      expect(result.visible).to eq(false)
    end

    it "診断なしでは最初の一歩として表示する" do
      result = described_class.call(customer)

      expect(result.visible).to eq(true)
      expect(result.title).to eq("おかえりなさい 🎵")
      expect(result.message).to include("また今日から音楽を楽しみましょう")
      expect(result.latest_activity_at).to be_nil
    end

    it "3日空きではおかえりメッセージを返す" do
      create(:singing_diagnosis, :completed, customer: customer, created_at: 3.days.ago)

      result = described_class.call(customer)

      expect(result.visible).to eq(true)
      expect(result.title).to eq("おかえりなさい 🎵")
      expect(result.message).to include("少し間が空いても大丈夫")
    end

    it "7日空きでは一歩だけのメッセージを返す" do
      create(:singing_diagnosis, :completed, customer: customer, created_at: 7.days.ago)

      result = described_class.call(customer)

      expect(result.visible).to eq(true)
      expect(result.title).to eq("あなたの音楽を待っています 🎤")
      expect(result.message).to include("まずは一歩だけ")
    end

    it "30日空きではいつでも帰ってきてくださいメッセージを返す" do
      create(:singing_diagnosis, :completed, customer: customer, created_at: 30.days.ago)

      result = described_class.call(customer)

      expect(result.visible).to eq(true)
      expect(result.title).to eq("また歌いたくなったら、")
      expect(result.message).to include("いつでも帰ってきてください")
    end

    it "最近活動ありでは表示しない" do
      create(:singing_diagnosis, :completed, customer: customer, created_at: 2.days.ago)

      result = described_class.call(customer)

      expect(result.visible).to eq(false)
    end

    it "診断なし・応援ありなら最近活動として表示しない" do
      create(:singing_profile_reaction, customer: customer, created_at: 1.day.ago)

      result = described_class.call(customer)

      expect(result.visible).to eq(false)
      expect(result.latest_activity_at).to be_within(1.second).of(1.day.ago)
      expect(result.activity_source).to eq(:profile_reaction_sent)
    end

    it "診断は古いが応援送信が最近なら表示しない" do
      create(:singing_diagnosis, :completed, customer: customer, created_at: 30.days.ago)
      create(:singing_profile_reaction, customer: customer, created_at: 2.days.ago)

      result = described_class.call(customer)

      expect(result.visible).to eq(false)
      expect(result.latest_activity_at).to be_within(1.second).of(2.days.ago)
      expect(result.activity_source).to eq(:profile_reaction_sent)
    end

    it "応援受信が最近なら表示しない" do
      sender = create(:customer, domain_name: "singing")
      create(:singing_diagnosis, :completed, customer: customer, created_at: 7.days.ago)
      create(:singing_profile_reaction, customer: sender, target_customer: customer, created_at: 2.days.ago)

      result = described_class.call(customer)

      expect(result.visible).to eq(false)
      expect(result.latest_activity_at).to be_within(1.second).of(2.days.ago)
      expect(result.activity_source).to eq(:profile_reaction_received)
    end

    it "チャレンジ進捗が最近なら表示しない" do
      create(:singing_diagnosis, :completed, customer: customer, created_at: 7.days.ago)
      create(:singing_ai_challenge_progress, customer: customer, updated_at: 1.day.ago)

      result = described_class.call(customer)

      expect(result.visible).to eq(false)
      expect(result.latest_activity_at).to be_within(1.second).of(1.day.ago)
      expect(result.activity_source).to eq(:ai_challenge_progress)
    end

    it "すべて古いなら表示する" do
      create(:singing_diagnosis, :completed, customer: customer, created_at: 30.days.ago)
      create(:singing_profile_reaction, customer: customer, created_at: 7.days.ago)

      result = described_class.call(customer)

      expect(result.visible).to eq(true)
      expect(result.title).to eq("あなたの音楽を待っています 🎤")
      expect(result.latest_activity_at).to be_within(1.second).of(7.days.ago)
      expect(result.activity_source).to eq(:profile_reaction_sent)
    end

    it "CTA path は新規診断画面を返す" do
      result = described_class.call(customer)

      expect(result.cta_label).to eq("今日の診断をする")
      expect(result.cta_path).to eq(Rails.application.routes.url_helpers.new_singing_diagnosis_path)
    end
  end
end
