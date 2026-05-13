require 'rails_helper'

RSpec.describe SingingDiagnoses::ChallengeResultFeedback do
  let(:customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let(:other_customer) { FactoryBot.create(:customer, domain_name: "singing") }

  describe "#call" do
    it "前回のAIチャレンジ対象スコアの差分を返すこと" do
      previous_diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        created_at: 10.days.ago,
        rhythm_score: 70
      )
      FactoryBot.create(
        :singing_ai_challenge_progress,
        customer: customer,
        target_key: "rhythm",
        tried: true,
        challenge_month: previous_diagnosis.created_at.to_date.beginning_of_month,
        created_at: 8.days.ago
      )
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        created_at: Time.current,
        rhythm_score: 76
      )

      feedback = described_class.new(customer, diagnosis).call

      expect(feedback[:target_key]).to eq "rhythm"
      expect(feedback[:target_label]).to eq "リズム"
      expect(feedback[:challenge_title]).to eq "リズム安定チャレンジ"
      expect(feedback[:previous_score]).to eq 70
      expect(feedback[:current_score]).to eq 76
      expect(feedback[:delta]).to eq 6
      expect(feedback[:delta_label]).to eq "+6"
      expect(feedback[:score_sentence]).to eq "前回よりリズムスコアが +6 点アップしています。"
      expect(feedback[:message]).to eq "少しずつ練習の成果が出ています！"
    end

    it "current_customer以外のprogressを参照しないこと" do
      FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        created_at: 10.days.ago,
        rhythm_score: 70
      )
      FactoryBot.create(
        :singing_ai_challenge_progress,
        customer: other_customer,
        target_key: "rhythm",
        tried: true,
        created_at: 8.days.ago
      )
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        created_at: Time.current,
        rhythm_score: 76
      )

      expect(described_class.new(customer, diagnosis).call).to be_nil
    end

    it "前回診断がない場合はnilを返すこと" do
      FactoryBot.create(
        :singing_ai_challenge_progress,
        customer: customer,
        target_key: "pitch",
        tried: true,
        created_at: 8.days.ago
      )
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        created_at: Time.current,
        pitch_score: 80
      )

      expect(described_class.new(customer, diagnosis).call).to be_nil
    end

    it "habitチャレンジはスコア差分表示の対象外にすること" do
      FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        created_at: 10.days.ago,
        pitch_score: 70
      )
      FactoryBot.create(
        :singing_ai_challenge_progress,
        customer: customer,
        target_key: "habit",
        tried: true,
        created_at: 8.days.ago
      )
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        created_at: Time.current,
        pitch_score: 80
      )

      expect(described_class.new(customer, diagnosis).call).to be_nil
    end
  end
end
