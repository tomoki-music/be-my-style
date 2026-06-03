require "rails_helper"

RSpec.describe Singing::CommunityMemoryBuilder do
  describe ".call" do
    let(:customer) { create(:customer, domain_name: "singing") }

    it "nil customerでは非表示Resultを返す" do
      result = described_class.call(nil)

      expect(result).to be_a(described_class::Result)
      expect(result.active?).to eq(false)
      expect(result.title).to be_nil
      expect(result.cta_path).to be_nil
    end

    it "活動がなければ非表示Resultを返す" do
      result = described_class.call(customer)

      expect(result.active?).to eq(false)
      expect(result.activity_source).to be_nil
    end

    it "completed diagnosis があると診断記憶を返す" do
      diagnosis = create(:singing_diagnosis, :completed, customer: customer, created_at: 2.days.ago)

      result = described_class.call(customer)

      expect(result.active?).to eq(true)
      expect(result.icon).to eq("🎤")
      expect(result.title).to eq("前回は歌唱診断を完了しました")
      expect(result.message).to eq("前回の成長を振り返ってみましょう。")
      expect(result.cta_label).to eq("診断履歴を見る")
      expect(result.cta_path).to eq(Rails.application.routes.url_helpers.singing_diagnoses_path)
      expect(result.activity_source).to eq(:diagnosis)
      expect(result.latest_activity_at).to be_within(1.second).of(diagnosis.created_at)
    end

    it "応援送信があると応援送信記憶を返す" do
      reaction = create(:singing_profile_reaction, customer: customer, created_at: 1.day.ago)

      result = described_class.call(customer)

      expect(result.active?).to eq(true)
      expect(result.icon).to eq("🔥")
      expect(result.title).to eq("前回は仲間を応援しました")
      expect(result.message).to eq("応援はコミュニティを育てます。")
      expect(result.cta_label).to eq("仲間の活動を見る")
      expect(result.cta_path).to eq("#community-feed")
      expect(result.activity_source).to eq(:reaction_sent)
      expect(result.latest_activity_at).to be_within(1.second).of(reaction.created_at)
    end

    it "応援受信があると応援受信記憶を返す" do
      sender = create(:customer, domain_name: "singing")
      reaction = create(:singing_profile_reaction, customer: sender, target_customer: customer, created_at: 1.day.ago)

      result = described_class.call(customer)

      expect(result.active?).to eq(true)
      expect(result.icon).to eq("👏")
      expect(result.title).to eq("前回あなたの活動に応援が届きました")
      expect(result.message).to eq("応援を受け取ってみましょう。")
      expect(result.cta_label).to eq("応援を見る")
      expect(result.cta_path).to eq("#encouragement-inbox")
      expect(result.activity_source).to eq(:reaction_received)
      expect(result.latest_activity_at).to be_within(1.second).of(reaction.created_at)
    end

    it "challenge progress があるとチャレンジ記憶を返す" do
      progress = create(:singing_ai_challenge_progress, customer: customer, completed: false, updated_at: 1.day.ago)

      result = described_class.call(customer)

      expect(result.active?).to eq(true)
      expect(result.icon).to eq("🏆")
      expect(result.title).to eq("チャレンジ継続中です")
      expect(result.message).to eq("達成まであと少しです。")
      expect(result.cta_label).to eq("チャレンジを見る")
      expect(result.cta_path).to eq(Rails.application.routes.url_helpers.singing_challenges_path)
      expect(result.activity_source).to eq(:challenge_progress)
      expect(result.latest_activity_at).to be_within(1.second).of(progress.updated_at)
    end

    it "優先順位順に診断記憶を優先する" do
      create(:singing_profile_reaction, customer: customer, created_at: 1.hour.ago)
      create(:singing_diagnosis, :completed, customer: customer, created_at: 2.days.ago)

      result = described_class.call(customer)

      expect(result.activity_source).to eq(:diagnosis)
    end
  end
end
