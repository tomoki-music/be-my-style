require 'rails_helper'

RSpec.describe SingingDiagnoses::GenerateAiCommentJob, type: :job do
  describe "#perform" do
    it "premiumユーザーのcompleted診断にAIコメントを保存すること" do
      customer = FactoryBot.create(:customer, domain_name: "singing")
      customer.create_subscription!(status: "active", plan: "premium")
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed)

      allow(SingingDiagnoses::AiCommentGenerator).to receive(:call).and_return("AIからの練習コメントです。")

      described_class.perform_now(diagnosis.id)

      diagnosis.reload
      expect(diagnosis).to be_ai_comment_completed
      expect(diagnosis.ai_comment).to eq "AIからの練習コメントです。"
      expect(diagnosis.ai_commented_at).to be_present
    end

    it "premium以外のユーザーでは生成しないこと" do
      diagnosis = FactoryBot.create(:singing_diagnosis, status: :completed)

      described_class.perform_now(diagnosis.id)

      expect(diagnosis.reload).to be_ai_comment_not_requested
      expect(diagnosis.ai_comment).to be_blank
    end

    it "生成に失敗しても診断結果はcompletedのままにすること" do
      customer = FactoryBot.create(:customer, domain_name: "singing")
      customer.create_subscription!(status: "active", plan: "premium")
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed)

      allow(SingingDiagnoses::AiCommentGenerator).to receive(:call).and_raise(StandardError, "boom")

      described_class.perform_now(diagnosis.id)

      diagnosis.reload
      expect(diagnosis).to be_completed
      expect(diagnosis).to be_ai_comment_failed
      expect(diagnosis.ai_comment_failure_reason).to include("boom")
    end

    it "開発環境でAPIキー未設定の場合はフォールバックコメントを保存してcompletedにすること" do
      customer = FactoryBot.create(:customer, domain_name: "singing")
      customer.create_subscription!(status: "active", plan: "premium")
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed)

      allow(SingingDiagnoses::AiCommentGenerator).to receive(:call).and_raise(
        SingingDiagnoses::OpenAiResponsesClient::ConfigurationError,
        "OpenAI API key is not configured."
      )
      allow(Rails.env).to receive(:development?).and_return(true)

      described_class.perform_now(diagnosis.id)

      diagnosis.reload
      expect(diagnosis).to be_completed
      expect(diagnosis).to be_ai_comment_completed
      expect(diagnosis.ai_comment).to include("今回の")
      expect(diagnosis.ai_comment).not_to include("APIキー")
      expect(diagnosis.ai_comment).not_to include("本番用AIコメント")
      expect(diagnosis.ai_commented_at).to be_present
    end

    it "非開発環境でAPIキー未設定の場合はai_comment_failedにすること" do
      customer = FactoryBot.create(:customer, domain_name: "singing")
      customer.create_subscription!(status: "active", plan: "premium")
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed)

      allow(SingingDiagnoses::AiCommentGenerator).to receive(:call).and_raise(
        SingingDiagnoses::OpenAiResponsesClient::ConfigurationError,
        "OpenAI API key is not configured."
      )
      allow(Rails.env).to receive(:development?).and_return(false)

      described_class.perform_now(diagnosis.id)

      diagnosis.reload
      expect(diagnosis).to be_completed
      expect(diagnosis).to be_ai_comment_failed
      expect(diagnosis.ai_comment_failure_reason).to include("OpenAI API key is not configured")
      expect(diagnosis.ai_comment_failure_reason).to include("ai_comment_configuration")
      expect(diagnosis.result_payload["ai_comment_debug"]).to include(
        "status" => "failed",
        "category" => "configuration",
        "error_class" => "SingingDiagnoses::OpenAiResponsesClient::ConfigurationError"
      )
    end

    it "OpenAI timeoutの場合は原因を分類してdebug情報を保存すること" do
      customer = FactoryBot.create(:customer, domain_name: "singing")
      customer.create_subscription!(status: "active", plan: "premium")
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        result_payload: { "common" => { "overall_score" => 75 } }
      )

      allow(SingingDiagnoses::AiCommentGenerator).to receive(:call).and_raise(
        SingingDiagnoses::OpenAiResponsesClient::TimeoutError,
        "OpenAI request timed out: Net::ReadTimeout: Net::ReadTimeout"
      )

      described_class.perform_now(diagnosis.id)

      diagnosis.reload
      expect(diagnosis).to be_completed
      expect(diagnosis).to be_ai_comment_failed
      expect(diagnosis.ai_comment_failure_reason).to include("ai_comment_timeout")
      expect(diagnosis.result_payload["common"]).to eq("overall_score" => 75)
      expect(diagnosis.result_payload["ai_comment_debug"]).to include(
        "status" => "failed",
        "category" => "timeout",
        "error_class" => "SingingDiagnoses::OpenAiResponsesClient::TimeoutError"
      )
      expect(diagnosis.result_payload["ai_comment_debug"]["message"]).not_to include("test-key")
    end

    it "OpenAIレスポンス形式不正の場合は原因を分類して保存すること" do
      customer = FactoryBot.create(:customer, domain_name: "singing")
      customer.create_subscription!(status: "active", plan: "premium")
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed)

      allow(SingingDiagnoses::AiCommentGenerator).to receive(:call).and_raise(
        SingingDiagnoses::OpenAiResponsesClient::ResponseFormatError,
        "OpenAI response did not include text output"
      )

      described_class.perform_now(diagnosis.id)

      diagnosis.reload
      expect(diagnosis).to be_ai_comment_failed
      expect(diagnosis.ai_comment_failure_reason).to include("ai_comment_response_format")
      expect(diagnosis.result_payload["ai_comment_debug"]["category"]).to eq("response_format")
    end

    describe "開発環境フォールバックのマンネリ防止" do
      let(:customer) do
        c = FactoryBot.create(:customer, domain_name: "singing")
        c.create_subscription!(status: "active", plan: "premium")
        c
      end

      before do
        allow(SingingDiagnoses::AiCommentGenerator).to receive(:call).and_raise(
          SingingDiagnoses::OpenAiResponsesClient::ConfigurationError,
          "OpenAI API key is not configured."
        )
        allow(Rails.env).to receive(:development?).and_return(true)
      end

      it "初回診断のフォールバックには初回向け一文が含まれること" do
        diagnosis = FactoryBot.create(
          :singing_diagnosis,
          customer: customer,
          status: :completed,
          overall_score: 70,
          pitch_score: 65,
          rhythm_score: 72,
          expression_score: 68
        )

        described_class.perform_now(diagnosis.id)

        diagnosis.reload
        expect(diagnosis).to be_ai_comment_completed
        expect(diagnosis.ai_comment).to include("はじめての診断")
        expect(diagnosis.ai_comment).to include("今回の")
      end

      it "前回より大きくスコアが伸びた場合はフォールバックに伸び一文が含まれること" do
        FactoryBot.create(
          :singing_diagnosis,
          customer: customer,
          status: :completed,
          overall_score: 60,
          pitch_score: 58,
          rhythm_score: 62,
          expression_score: 60,
          created_at: 1.day.ago
        )
        diagnosis = FactoryBot.create(
          :singing_diagnosis,
          customer: customer,
          status: :completed,
          overall_score: 75,
          pitch_score: 72,
          rhythm_score: 75,
          expression_score: 73,
          created_at: Time.current
        )

        described_class.perform_now(diagnosis.id)

        diagnosis.reload
        expect(diagnosis).to be_ai_comment_completed
        expect(diagnosis.ai_comment).to include("前回より全体スコアが伸びています")
        expect(diagnosis.ai_comment).to include("今回の")
      end

      it "前回と同水準の場合はスコア比較一文なしで今回の診断コメントを返すこと" do
        FactoryBot.create(
          :singing_diagnosis,
          customer: customer,
          status: :completed,
          overall_score: 70,
          pitch_score: 68,
          rhythm_score: 70,
          expression_score: 72,
          created_at: 1.day.ago
        )
        diagnosis = FactoryBot.create(
          :singing_diagnosis,
          customer: customer,
          status: :completed,
          overall_score: 71,
          pitch_score: 69,
          rhythm_score: 71,
          expression_score: 73,
          created_at: Time.current
        )

        described_class.perform_now(diagnosis.id)

        diagnosis.reload
        expect(diagnosis).to be_ai_comment_completed
        expect(diagnosis.ai_comment).to include("今回の")
        expect(diagnosis.ai_comment).not_to include("はじめての診断")
      end
    end
  end
end
