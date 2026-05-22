require "rails_helper"

RSpec.describe Singing::RunRecapMovieAutoRetriesJob, type: :job do
  include ActiveJob::TestHelper

  describe "#perform" do
    it "RecapMovieAutoRetryService.call を呼ぶこと" do
      dummy_result = Singing::RecapMovieAutoRetryService::Result.new(
        processed_count: 0,
        succeeded_count: 0,
        skipped_count:   0,
        failed_count:    0
      )
      allow(Singing::RecapMovieAutoRetryService).to receive(:call).and_return(dummy_result)

      described_class.perform_now

      expect(Singing::RecapMovieAutoRetryService).to have_received(:call).once
    end

    it "result を返すこと" do
      dummy_result = Singing::RecapMovieAutoRetryService::Result.new(
        processed_count: 2,
        succeeded_count: 1,
        skipped_count:   1,
        failed_count:    0
      )
      allow(Singing::RecapMovieAutoRetryService).to receive(:call).and_return(dummy_result)

      result = described_class.perform_now

      expect(result.processed_count).to eq(2)
      expect(result.succeeded_count).to eq(1)
    end

    it "エラーなしで完了すること" do
      allow(Singing::RecapMovieAutoRetryService).to receive(:call).and_return(
        Singing::RecapMovieAutoRetryService::Result.new(
          processed_count: 0, succeeded_count: 0, skipped_count: 0, failed_count: 0
        )
      )
      expect { described_class.perform_now }.not_to raise_error
    end
  end
end
