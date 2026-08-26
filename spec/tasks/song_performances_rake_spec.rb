require "rails_helper"
require "rake"

RSpec.describe "song_performances:backfill rakeタスク" do
  let(:customer) { FactoryBot.create(:customer) }
  let(:withdrawn_customer) { FactoryBot.create(:customer, is_deleted: true) }

  let(:ended_event) do
    FactoryBot.create(
      :event,
      :event_with_songs,
      event_start_time: 3.days.ago,
      event_end_time: 2.days.ago,
      event_entry_deadline: 4.days.ago
    )
  end
  let(:upcoming_event) do
    FactoryBot.create(
      :event,
      :event_with_songs,
      event_start_time: 3.days.from_now,
      event_end_time: 4.days.from_now,
      event_entry_deadline: 2.days.from_now
    )
  end

  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("song_performances:backfill")
  end

  def run_task
    Rake::Task["song_performances:backfill"].invoke
  ensure
    Rake::Task["song_performances:backfill"].reenable
  end

  def entry_for(event, customer, part_name: "Vocal")
    song = FactoryBot.create(:song, event: event)
    join_part = FactoryBot.create(:join_part, song: song, join_part_name: part_name)
    FactoryBot.create(:join_part_customer, join_part: join_part, customer: customer)
  end

  it "終了済みイベントのエントリーのみ演奏実績として反映すること" do
    entry_for(ended_event, customer)
    entry_for(upcoming_event, customer)

    expect { run_task }.to change(SongPerformance, :count).by(1)
    expect(SongPerformance.last.event_id).to eq ended_event.id
  end

  it "退会済み・キャンセル済みエントリーは反映しないこと" do
    entry_for(ended_event, withdrawn_customer)
    song = FactoryBot.create(:song, event: ended_event)
    join_part = FactoryBot.create(:join_part, song: song, join_part_name: "Guitar")
    cancelled = FactoryBot.create(:join_part_customer, join_part: join_part, customer: customer)
    cancelled.destroy

    expect { run_task }.not_to change(SongPerformance, :count)
  end

  it "複数回実行しても重複しないこと" do
    entry_for(ended_event, customer)

    run_task
    expect { run_task }.not_to change(SongPerformance, :count)
  end

  it "DRY_RUN=trueの場合はデータを更新しないこと" do
    entry_for(ended_event, customer)

    original_env = ENV["DRY_RUN"]
    ENV["DRY_RUN"] = "true"
    begin
      expect { run_task }.not_to change(SongPerformance, :count)
    ensure
      ENV["DRY_RUN"] = original_env
    end
  end
end
