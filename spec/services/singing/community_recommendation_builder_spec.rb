require "rails_helper"

RSpec.describe Singing::CommunityRecommendationBuilder do
  describe ".call" do
    let(:customer) { create(:customer, domain_name: "singing") }

    it "nil customerでは非表示Resultを返す" do
      result = described_class.call(nil)

      expect(result).to be_a(described_class::Result)
      expect(result.active?).to eq(false)
      expect(result.title).to be_nil
      expect(result.cta_path).to be_nil
    end

    it "直近活動がdiagnosisならCommunity Feedへの推薦を返す" do
      create(:singing_profile_reaction, customer: customer, created_at: 2.days.ago)
      create(:singing_diagnosis, :completed, customer: customer, created_at: 1.hour.ago)

      result = described_class.call(customer)

      expect(result.active?).to eq(true)
      expect(result.icon).to eq("🎤")
      expect(result.title).to eq("次は仲間の活動も見てみましょう")
      expect(result.message).to eq("音楽は一人でも楽しめますが、\n仲間とつながるともっと楽しくなります。")
      expect(result.cta_label).to eq("Community Feedを見る")
      expect(result.cta_path).to eq(Rails.application.routes.url_helpers.singing_growth_feed_path)
    end

    it "直近活動がreaction_sentなら歌唱診断への推薦を返す" do
      create(:singing_diagnosis, :completed, customer: customer, created_at: 2.days.ago)
      create(:singing_profile_reaction, customer: customer, created_at: 1.hour.ago)

      result = described_class.call(customer)

      expect(result.active?).to eq(true)
      expect(result.icon).to eq("🔥")
      expect(result.title).to eq("応援ありがとうございます")
      expect(result.message).to eq("今度は自分の成長も記録してみましょう。")
      expect(result.cta_label).to eq("歌唱診断をする")
      expect(result.cta_path).to eq(Rails.application.routes.url_helpers.new_singing_diagnosis_path)
    end

    it "直近活動がreaction_receivedならチャレンジへの推薦を返す" do
      sender = create(:customer, domain_name: "singing")
      create(:singing_diagnosis, :completed, customer: customer, created_at: 2.days.ago)
      create(:singing_profile_reaction, customer: sender, target_customer: customer, created_at: 1.hour.ago)

      result = described_class.call(customer)

      expect(result.active?).to eq(true)
      expect(result.icon).to eq("👏")
      expect(result.title).to eq("仲間から応援が届いています")
      expect(result.message).to eq("その勢いで次の挑戦に進みましょう。")
      expect(result.cta_label).to eq("チャレンジを見る")
      expect(result.cta_path).to eq(Rails.application.routes.url_helpers.singing_challenges_path)
    end

    it "直近活動がchallenge_progressならChallengeへの推薦を返す" do
      create(:singing_diagnosis, :completed, customer: customer, created_at: 2.days.ago)
      create(:singing_ai_challenge_progress, customer: customer, completed: false, updated_at: 1.hour.ago)

      result = described_class.call(customer)

      expect(result.active?).to eq(true)
      expect(result.icon).to eq("🏆")
      expect(result.title).to eq("あと少しで達成です")
      expect(result.message).to eq("継続は大きな成長につながります。")
      expect(result.cta_label).to eq("Challengeを見る")
      expect(result.cta_path).to eq(Rails.application.routes.url_helpers.singing_challenges_path)
    end

    it "完了済みchallengeが新しくても未完了challengeを推薦材料にする" do
      create(:singing_diagnosis, :completed, customer: customer, created_at: 3.days.ago)
      create(:singing_ai_challenge_progress, customer: customer, target_key: "pitch", completed: false, updated_at: 2.days.ago)
      create(:singing_ai_challenge_progress, customer: customer, target_key: "rhythm", completed: true, updated_at: 1.day.ago)

      result = described_class.call(customer)

      expect(result.active?).to eq(true)
      expect(result.icon).to eq("🏆")
      expect(result.cta_label).to eq("Challengeを見る")
    end

    it "活動がなければfallback推薦を返す" do
      result = described_class.call(customer)

      expect(result.active?).to eq(true)
      expect(result.icon).to eq("🎵")
      expect(result.title).to eq("今日も音楽を楽しみましょう")
      expect(result.message).to eq("小さな一歩から始まります。")
      expect(result.cta_label).to eq("歌唱診断をする")
      expect(result.cta_path).to eq(Rails.application.routes.url_helpers.new_singing_diagnosis_path)
    end
  end
end
