module Singing
  class CaptureRecapMovieStorageSnapshotJob < ApplicationJob
    queue_as :default

    def perform(date_str = nil)
      date   = date_str ? Date.parse(date_str) : Date.current
      result = Singing::RecapMovieStorageSnapshotService.call(date: date)

      if result.skipped
        Rails.logger.info "[CaptureRecapMovieStorageSnapshotJob] skipped: snapshot already exists for #{date}"
      else
        Rails.logger.info "[CaptureRecapMovieStorageSnapshotJob] snapshot captured for #{date} " \
                          "(id=#{result.snapshot.id})"
      end
    end
  end
end
