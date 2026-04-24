require 'rails_helper'

RSpec.describe SingingDiagnoses::ResultPersister do
  include ActiveJob::TestHelper

  describe ".call" do
    around do |example|
      original_adapter = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
      clear_enqueued_jobs
      clear_performed_jobs
      example.run
      clear_enqueued_jobs
      clear_performed_jobs
      ActiveJob::Base.queue_adapter = original_adapter
    end

    it "結果payloadを保存してcompletedにすること" do
      diagnosis = FactoryBot.create(:singing_diagnosis, status: :processing)
      payload = {
        overall_score: 86,
        pitch_score: 82,
        rhythm_score: 90,
        expression_score: 84
      }

      expect(described_class.call(diagnosis, payload)).to eq true

      diagnosis.reload
      expect(diagnosis).to be_completed
      expect(diagnosis.overall_score).to eq 86
      expect(diagnosis.pitch_score).to eq 82
      expect(diagnosis.rhythm_score).to eq 90
      expect(diagnosis.expression_score).to eq 84
      expect(diagnosis.result_payload).to eq payload
      expect(diagnosis.diagnosed_at).to be_present
      expect(diagnosis.failure_reason).to be_blank
    end

    it "文字列keyのpayloadも保存できること" do
      diagnosis = FactoryBot.create(:singing_diagnosis, status: :processing)
      payload = {
        "overall_score" => "70",
        "pitch_score" => "71",
        "rhythm_score" => "72",
        "expression_score" => "73"
      }

      expect(described_class.call(diagnosis, payload)).to eq true

      expect(diagnosis.reload.overall_score).to eq 70
    end

    it "nested payloadのcommonからDBスコアを保存できること" do
      diagnosis = FactoryBot.create(:singing_diagnosis, status: :processing)
      payload = {
        "schema_version" => 1,
        "performance_type" => "vocal",
        "common" => {
          "overall_score" => 80,
          "pitch_score" => 81,
          "rhythm_score" => 82,
          "expression_score" => 83
        },
        "specific" => {
          "volume_score" => 78,
          "pronunciation_score" => 72,
          "relax_score" => 68,
          "mix_voice_score" => 70
        }
      }

      expect(described_class.call(diagnosis, payload)).to eq true

      diagnosis.reload
      expect(diagnosis).to be_completed
      expect(diagnosis.overall_score).to eq 80
      expect(diagnosis.pitch_score).to eq 81
      expect(diagnosis.rhythm_score).to eq 82
      expect(diagnosis.expression_score).to eq 83
      expect(diagnosis.result_payload).to eq payload
    end

    it "premiumユーザーの場合はAIコメント生成Jobをenqueueすること" do
      customer = FactoryBot.create(:customer, domain_name: "singing")
      customer.create_subscription!(status: "active", plan: "premium")
      diagnosis = FactoryBot.create(:singing_diagnosis, customer: customer, status: :processing)
      payload = {
        overall_score: 86,
        pitch_score: 82,
        rhythm_score: 90,
        expression_score: 84
      }

      expect do
        expect(described_class.call(diagnosis, payload)).to eq true
      end.to have_enqueued_job(SingingDiagnoses::GenerateAiCommentJob).with(diagnosis.id)

      expect(diagnosis.reload).to be_ai_comment_queued
      expect(diagnosis.ai_comment).to be_blank
    end

    it "不正payloadの場合はfailedにすること" do
      diagnosis = FactoryBot.create(:singing_diagnosis, status: :processing)

      expect(described_class.call(diagnosis, { overall_score: 80 })).to eq false
      expect(diagnosis.reload).to be_failed
      expect(diagnosis.failure_reason).to eq "Invalid analyzer payload"
    end
  end
end
