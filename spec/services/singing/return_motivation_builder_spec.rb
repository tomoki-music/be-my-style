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
      expect(result.message).to eq("ここから音楽の旅をはじめましょう。")
      expect(result.cta_label).to eq("まずは診断してみる")
      expect(result.cta_path).to eq(Rails.application.routes.url_helpers.new_singing_diagnosis_path)
      expect(result.latest_activity_at).to be_nil
      expect(result.activity_source).to be_nil
    end

    it "activity_source が diagnosis では診断に寄り添うメッセージを返す" do
      create(:singing_diagnosis, :completed, customer: customer, created_at: 3.days.ago)

      result = described_class.call(customer)

      expect(result.visible).to eq(true)
      expect(result.title).to eq("おかえりなさい 🎵")
      expect(result.message).to eq("前回の診断から少し間が空きました。\nまた今日から、自分のペースで歌を楽しみましょう。")
      expect(result.cta_label).to eq("今日の診断をする")
      expect(result.cta_path).to eq(Rails.application.routes.url_helpers.new_singing_diagnosis_path)
      expect(result.activity_source).to eq(:diagnosis)
    end

    it "activity_source が reaction_sent では応援していた活動に寄り添うメッセージを返す" do
      create(:singing_profile_reaction, customer: customer, created_at: 3.days.ago)

      result = described_class.call(customer)

      expect(result.visible).to eq(true)
      expect(result.message).to eq("前に仲間を応援していましたね。\nまた音楽の輪に戻ってみませんか。")
      expect(result.cta_label).to eq("仲間の活動を見る")
      expect(result.cta_path).to eq("#community-feed")
      expect(result.activity_source).to eq(:reaction_sent)
    end

    it "activity_source が reaction_received では届いた応援に寄り添うメッセージを返す" do
      sender = create(:customer, domain_name: "singing")
      create(:singing_profile_reaction, customer: sender, target_customer: customer, created_at: 3.days.ago)

      result = described_class.call(customer)

      expect(result.visible).to eq(true)
      expect(result.message).to eq("仲間からの応援が届いています。\nまた少しずつ、歌との時間を楽しみましょう。")
      expect(result.cta_label).to eq("応援を見に行く")
      expect(result.cta_path).to eq("#encouragement-inbox")
      expect(result.activity_source).to eq(:reaction_received)
    end

    it "activity_source が challenge_progress では挑戦に寄り添うメッセージを返す" do
      create(:singing_ai_challenge_progress, customer: customer, updated_at: 3.days.ago)

      result = described_class.call(customer)

      expect(result.visible).to eq(true)
      expect(result.message).to eq("前に挑戦していたテーマがあります。\n完璧じゃなくて大丈夫。まずは一歩だけ。")
      expect(result.cta_label).to eq("チャレンジを見る")
      expect(result.cta_path).to eq(Rails.application.routes.url_helpers.singing_challenges_path)
      expect(result.activity_source).to eq(:challenge_progress)
    end

    it "7日空きでは待っていますタイトルを返す" do
      create(:singing_diagnosis, :completed, customer: customer, created_at: 7.days.ago)

      result = described_class.call(customer)

      expect(result.visible).to eq(true)
      expect(result.title).to eq("あなたの音楽を待っています 🎤")
      expect(result.message).to include("自分のペースで歌を楽しみましょう")
    end

    it "30日空きではまた歌いたくなったらタイトルを返す" do
      create(:singing_diagnosis, :completed, customer: customer, created_at: 30.days.ago)

      result = described_class.call(customer)

      expect(result.visible).to eq(true)
      expect(result.title).to eq("また歌いたくなったら、")
      expect(result.message).to include("自分のペースで歌を楽しみましょう")
    end

    it "最近活動ありでは表示しない" do
      create(:singing_diagnosis, :completed, customer: customer, created_at: 2.days.ago)

      result = described_class.call(customer)

      expect(result.visible).to eq(false)
      expect(result.cta_label).to be_nil
      expect(result.cta_path).to be_nil
    end

    it "診断なし・応援ありなら最近活動として表示しない" do
      create(:singing_profile_reaction, customer: customer, created_at: 1.day.ago)

      result = described_class.call(customer)

      expect(result.visible).to eq(false)
      expect(result.latest_activity_at).to be_within(1.second).of(1.day.ago)
      expect(result.activity_source).to eq(:reaction_sent)
    end

    it "診断は古いが応援送信が最近なら表示しない" do
      create(:singing_diagnosis, :completed, customer: customer, created_at: 30.days.ago)
      create(:singing_profile_reaction, customer: customer, created_at: 2.days.ago)

      result = described_class.call(customer)

      expect(result.visible).to eq(false)
      expect(result.latest_activity_at).to be_within(1.second).of(2.days.ago)
      expect(result.activity_source).to eq(:reaction_sent)
    end

    it "応援受信が最近なら表示しない" do
      sender = create(:customer, domain_name: "singing")
      create(:singing_diagnosis, :completed, customer: customer, created_at: 7.days.ago)
      create(:singing_profile_reaction, customer: sender, target_customer: customer, created_at: 2.days.ago)

      result = described_class.call(customer)

      expect(result.visible).to eq(false)
      expect(result.latest_activity_at).to be_within(1.second).of(2.days.ago)
      expect(result.activity_source).to eq(:reaction_received)
    end

    it "チャレンジ進捗が最近なら表示しない" do
      create(:singing_diagnosis, :completed, customer: customer, created_at: 7.days.ago)
      create(:singing_ai_challenge_progress, customer: customer, updated_at: 1.day.ago)

      result = described_class.call(customer)

      expect(result.visible).to eq(false)
      expect(result.latest_activity_at).to be_within(1.second).of(1.day.ago)
      expect(result.activity_source).to eq(:challenge_progress)
    end

    it "すべて古いなら表示する" do
      create(:singing_diagnosis, :completed, customer: customer, created_at: 30.days.ago)
      create(:singing_profile_reaction, customer: customer, created_at: 7.days.ago)

      result = described_class.call(customer)

      expect(result.visible).to eq(true)
      expect(result.title).to eq("あなたの音楽を待っています 🎤")
      expect(result.message).to eq("前に仲間を応援していましたね。\nまた音楽の輪に戻ってみませんか。")
      expect(result.latest_activity_at).to be_within(1.second).of(7.days.ago)
      expect(result.activity_source).to eq(:reaction_sent)
    end

  end

  describe "activity source maps" do
    it "message と CTA のキーを揃えている" do
      expected_keys = %i[diagnosis reaction_sent reaction_received challenge_progress default]

      expect(described_class::MESSAGE_MAP.keys).to eq(expected_keys)
      expect(described_class::CTA_MAP.keys).to eq(expected_keys)
    end
  end
end
