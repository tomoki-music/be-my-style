require 'rails_helper'

RSpec.describe SongPerformances::EventSync, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  let(:customer) { FactoryBot.create(:customer) }
  let(:other_customer) { FactoryBot.create(:customer) }
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

  def entry_for(event, customer, part_name: "Vocal")
    song = FactoryBot.create(:song, event: event)
    join_part = FactoryBot.create(:join_part, song: song, join_part_name: part_name)
    FactoryBot.create(:join_part_customer, join_part: join_part, customer: customer)
    join_part
  end

  describe '終了済みイベントの反映' do
    it '終了済みイベントのエントリーがSongPerformanceとして作成されること' do
      join_part = entry_for(ended_event, customer)

      expect {
        SongPerformances::EventSync.call(ended_event)
      }.to change(SongPerformance, :count).by(1)

      performance = SongPerformance.last
      expect(performance.customer_id).to eq customer.id
      expect(performance.event_id).to eq ended_event.id
      expect(performance.part_name).to eq join_part.join_part_name
    end

    it '複数エントリーがあればまとめて作成されること' do
      entry_for(ended_event, customer, part_name: "Vocal")
      entry_for(ended_event, other_customer, part_name: "Guitar")

      expect {
        SongPerformances::EventSync.call(ended_event)
      }.to change(SongPerformance, :count).by(2)
    end
  end

  describe '開催前イベントは反映しないこと' do
    it 'SongPerformanceが作成されないこと' do
      entry_for(upcoming_event, customer)

      expect {
        SongPerformances::EventSync.call(upcoming_event)
      }.not_to change(SongPerformance, :count)
    end
  end

  describe 'キャンセル済みエントリーは反映しないこと' do
    it 'エントリー取消済み(JoinPartCustomer削除済み)の分は対象に含まれないこと' do
      song = FactoryBot.create(:song, event: ended_event)
      join_part = FactoryBot.create(:join_part, song: song, join_part_name: "Vocal")
      join_part_customer = FactoryBot.create(:join_part_customer, join_part: join_part, customer: customer)
      join_part_customer.destroy

      expect {
        SongPerformances::EventSync.call(ended_event)
      }.not_to change(SongPerformance, :count)
    end
  end

  describe '退会済みcustomerの扱い' do
    it '退会済みcustomerのエントリーは反映しないこと' do
      entry_for(ended_event, withdrawn_customer)

      expect {
        SongPerformances::EventSync.call(ended_event)
      }.not_to change(SongPerformance, :count)
    end
  end

  describe '冪等性(複数回実行しても重複しないこと)' do
    it '2回実行しても2回目は新規作成されないこと' do
      entry_for(ended_event, customer)

      SongPerformances::EventSync.call(ended_event)
      expect {
        result = SongPerformances::EventSync.call(ended_event)
        expect(result.created).to eq 0
        expect(result.skipped).to eq 1
      }.not_to change(SongPerformance, :count)
    end
  end

  describe 'dry-run' do
    it 'DBを変更せず、件数だけが正しく集計されること' do
      entry_for(ended_event, customer, part_name: "Vocal")
      entry_for(ended_event, other_customer, part_name: "Guitar")
      entry_for(ended_event, withdrawn_customer, part_name: "Bass")

      result = nil
      expect {
        result = SongPerformances::EventSync.call(ended_event, dry_run: true)
      }.not_to change(SongPerformance, :count)

      expect(result.target).to eq 2
      expect(result.created).to eq 2
      expect(result.skipped).to eq 0
    end
  end
end
