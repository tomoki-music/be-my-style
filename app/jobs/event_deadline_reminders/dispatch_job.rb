module EventDeadlineReminders
  # bin/run_event_deadline_reminders から5分ごとに perform_now で呼ばれる想定。
  # 本番の ActiveJob は :async(Puma 内スレッド)のため perform_later で投入せず、
  # rails runner のプロセス内で同期実行してから終了する。
  class DispatchJob < ApplicationJob
    queue_as :default

    # デプロイ中はコード更新(git reset)からマイグレーションまでの間がある(その間にアセットの
    # プリコンパイルが数分かかる)。その間の定期実行は、新しい列を参照して失敗しないよう何もしない。
    # 送信予定を過ぎた分は、マイグレーション後の次回実行で従来どおり回収される。
    def perform
      if ActiveRecord::Base.connection.migration_context.needs_migration?
        Rails.logger.warn("[EventDeadlineReminders::DispatchJob] skip: pending migrations")
        return { skipped: :pending_migrations }
      end

      EventDeadlineReminders::Dispatcher.call
    end
  end
end
