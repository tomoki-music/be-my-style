module EventDeadlineReminders
  # bin/run_event_deadline_reminders から5分ごとに perform_now で呼ばれる想定。
  # 本番の ActiveJob は :async(Puma 内スレッド)のため perform_later で投入せず、
  # rails runner のプロセス内で同期実行してから終了する。
  class DispatchJob < ApplicationJob
    queue_as :default

    def perform
      EventDeadlineReminders::Dispatcher.call
    end
  end
end
