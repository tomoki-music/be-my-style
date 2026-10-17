require "rails_helper"
require "rake"

RSpec.describe "event_deadline_reminders:status" do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.none? { |task| task.name == "event_deadline_reminders:status" }
  end

  let(:task) { Rake::Task["event_deadline_reminders:status"] }

  after { task.reenable }

  it "送信もDB更新もせずに状態を表示すること" do
    event = FactoryBot.create(:event, :event_with_songs, event_entry_deadline: 1.day.from_now,
                                                         event_start_time: 3.days.from_now, event_end_time: 3.days.from_now + 2.hours)
    reminder = EventDeadlineReminder.create!(event: event, kind: "entry", channel: "mail", enabled: true,
                                             status: :sending, started_at: 1.hour.ago)

    expect { task.invoke }.to output(/sending=1.*STALE/m).to_stdout
    expect(reminder.reload).to be_sending
    expect(ActionMailer::Base.deliveries).to be_empty
  end
end
