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
  end
end
