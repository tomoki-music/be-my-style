require "rails_helper"

RSpec.describe Singing::RecapMovieAutoRetryPolicy, type: :service do
  let(:execution) { FactoryBot.create(:singing_recap_movie_batch_execution, :completed) }
  let(:customer)  { FactoryBot.create(:customer, domain_name: "singing") }

  def build_failure(error_class:, error_message:)
    FactoryBot.build(:singing_recap_movie_batch_failure,
                     singing_recap_movie_batch_execution: execution,
                     customer: customer,
                     error_class: error_class,
                     error_message: error_message)
  end

  describe ".auto_retryable?" do
    context "一時的なタイムアウト系エラー" do
      it "Timeout::Error + 'execution expired (timeout)' は対象であること" do
        f = build_failure(error_class: "Timeout::Error", error_message: "execution expired (timeout)")
        expect(described_class.auto_retryable?(f)).to be true
      end

      it "StandardError + 'process timeout' は対象であること" do
        f = build_failure(error_class: "StandardError", error_message: "process timeout exceeded")
        expect(described_class.auto_retryable?(f)).to be true
      end

      it "RuntimeError + 'temporary failure' は対象であること" do
        f = build_failure(error_class: "RuntimeError", error_message: "temporary failure in resolution")
        expect(described_class.auto_retryable?(f)).to be true
      end
    end

    context "Chromium / Render 系エラー" do
      it "'render process exited' は対象であること" do
        f = build_failure(error_class: "RuntimeError", error_message: "render process exited unexpectedly")
        expect(described_class.auto_retryable?(f)).to be true
      end

      it "'chromium crash' は対象であること" do
        f = build_failure(error_class: "StandardError", error_message: "chromium crash detected")
        expect(described_class.auto_retryable?(f)).to be true
      end

      it "'chrome' を含むエラーは対象であること" do
        f = build_failure(error_class: "StandardError", error_message: "chrome process failed")
        expect(described_class.auto_retryable?(f)).to be true
      end
    end

    context "FFmpeg 系エラー" do
      it "'FFmpeg exited 1' は対象であること" do
        f = build_failure(error_class: "RuntimeError", error_message: "FFmpeg exited 1 with stderr: ...")
        expect(described_class.auto_retryable?(f)).to be true
      end
    end

    context "永続的エラー（非対象）" do
      it "ActiveRecord::RecordInvalid は対象外であること" do
        f = build_failure(error_class: "ActiveRecord::RecordInvalid", error_message: "Validation failed")
        expect(described_class.auto_retryable?(f)).to be false
      end

      it "ActiveRecord::RecordNotFound は対象外であること" do
        f = build_failure(error_class: "ActiveRecord::RecordNotFound", error_message: "Couldn't find Customer")
        expect(described_class.auto_retryable?(f)).to be false
      end

      it "ArgumentError は対象外であること" do
        f = build_failure(error_class: "ArgumentError", error_message: "wrong number of arguments")
        expect(described_class.auto_retryable?(f)).to be false
      end

      it "NoMethodError は対象外であること" do
        f = build_failure(error_class: "NoMethodError", error_message: "undefined method 'foo'")
        expect(described_class.auto_retryable?(f)).to be false
      end

      it "マッチしない StandardError は対象外であること" do
        f = build_failure(error_class: "StandardError", error_message: "validation error")
        expect(described_class.auto_retryable?(f)).to be false
      end
    end
  end

  describe ".next_retry_at" do
    it "0回目は約5分後であること" do
      at = described_class.next_retry_at(0)
      expect(at).to be_within(5.seconds).of(5.minutes.from_now)
    end

    it "1回目は約15分後であること" do
      at = described_class.next_retry_at(1)
      expect(at).to be_within(5.seconds).of(15.minutes.from_now)
    end

    it "2回目は約30分後であること" do
      at = described_class.next_retry_at(2)
      expect(at).to be_within(5.seconds).of(30.minutes.from_now)
    end

    it "上限を超えた場合も最後のinterval（30分後）を返すこと" do
      at = described_class.next_retry_at(10)
      expect(at).to be_within(5.seconds).of(30.minutes.from_now)
    end
  end

  describe ".schedule_auto_retry_if_eligible!" do
    context "auto retry 対象のエラーを持つ failure" do
      let(:failure) do
        FactoryBot.create(:singing_recap_movie_batch_failure,
                          :timeout_error,
                          singing_recap_movie_batch_execution: execution,
                          customer: customer)
      end

      it "auto_retry_status が scheduled になること" do
        described_class.schedule_auto_retry_if_eligible!(failure)
        expect(failure.reload.auto_retry_status).to eq("scheduled")
      end

      it "next_auto_retry_at が設定されること" do
        described_class.schedule_auto_retry_if_eligible!(failure)
        expect(failure.reload.next_auto_retry_at).not_to be_nil
      end

      it "next_auto_retry_at が約5分後であること" do
        described_class.schedule_auto_retry_if_eligible!(failure)
        expect(failure.reload.next_auto_retry_at).to be_within(10.seconds).of(5.minutes.from_now)
      end
    end

    context "auto retry 非対象のエラーを持つ failure" do
      let(:failure) do
        FactoryBot.create(:singing_recap_movie_batch_failure,
                          singing_recap_movie_batch_execution: execution,
                          customer: customer,
                          error_class: "ActiveRecord::RecordInvalid",
                          error_message: "Validation failed")
      end

      it "auto_retry_status が not_applicable のままであること" do
        described_class.schedule_auto_retry_if_eligible!(failure)
        expect(failure.reload.auto_retry_status).to eq("not_applicable")
      end
    end
  end
end
