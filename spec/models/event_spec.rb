require 'rails_helper'

RSpec.describe Event, type: :model do
  let(:customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:other_customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:community) { FactoryBot.create(:community) }
  let(:event) { FactoryBot.create(:event, :event_with_songs, customer: customer, community: community) }
  let(:song) { FactoryBot.create(:song, event: event) }

  describe 'バリデーションのテスト' do
    context 'eventテーブルのカラムが不正' do
      it 'event_nameカラムが空欄でないこと' do
        event.event_name = ''
        expect(event.valid?).to eq false
      end
      it 'event_dateが空欄でないこと' do
        event.event_date = ''
        expect(event.valid?).to eq false
      end
      it 'entrance_feeが空欄でないこと' do
        event.entrance_fee = ''
        expect(event.valid?).to eq false
      end
      it 'addressが空欄でないこと' do
        event.address = ''
        expect(event.valid?).to eq false
      end
    end
  end
  describe 'アソシエーションのテスト' do
    context 'Songモデルとの関係' do
      it 'songsと1:Nとなっている' do
        expect(Event.reflect_on_association(:songs).macro).to eq :has_many
      end
    end
    context 'Customerモデルとの関係' do
      it 'customerと1:Nとなっている' do
        expect(Event.reflect_on_association(:customer).macro).to eq :belongs_to
      end
    end
    context 'Communityモデルとの関係' do
      it 'communityと1:Nとなっている' do
        expect(Event.reflect_on_association(:community).macro).to eq :belongs_to
      end
    end
    context 'Requestモデルとの関係' do
      it 'requestモデルと1:Nとなっている' do
        expect(Event.reflect_on_association(:requests).macro).to eq :has_many
      end
    end
  end

  describe '#status_key / #status_label' do
    let(:now) { Time.zone.parse('2026-01-10 12:00:00') }

    def event_at(start_time:, end_time:, entry_deadline:)
      FactoryBot.build(:event, event_start_time: start_time, event_end_time: end_time, event_entry_deadline: entry_deadline)
    end

    it '終了時刻を過ぎていれば終了済みになること' do
      event = event_at(start_time: now - 3.hours, end_time: now - 1.hour, entry_deadline: now - 5.hours)
      expect(event.status_key(now: now)).to eq :ended
      expect(event.status_label(now: now)).to eq '終了済み'
    end

    it '終了時刻ちょうどは終了済みになること(境界値)' do
      event = event_at(start_time: now - 3.hours, end_time: now, entry_deadline: now - 5.hours)
      expect(event.status_key(now: now)).to eq :ended
    end

    it '開始後・終了前は開催中になること' do
      event = event_at(start_time: now - 1.hour, end_time: now + 1.hour, entry_deadline: now - 5.hours)
      expect(event.status_key(now: now)).to eq :ongoing
      expect(event.status_label(now: now)).to eq '開催中'
    end

    it '開始時刻ちょうどは開催中になること(境界値)' do
      event = event_at(start_time: now, end_time: now + 1.hour, entry_deadline: now - 5.hours)
      expect(event.status_key(now: now)).to eq :ongoing
    end

    it '参加締切を過ぎ、開始前は募集終了になること' do
      event = event_at(start_time: now + 1.hour, end_time: now + 2.hours, entry_deadline: now - 30.minutes)
      expect(event.status_key(now: now)).to eq :entry_closed
      expect(event.status_label(now: now)).to eq '募集終了'
    end

    it '参加締切ちょうどは募集終了になること(境界値)' do
      event = event_at(start_time: now + 1.hour, end_time: now + 2.hours, entry_deadline: now)
      expect(event.status_key(now: now)).to eq :entry_closed
    end

    it '参加締切前は開催予定になること' do
      event = event_at(start_time: now + 2.hours, end_time: now + 3.hours, entry_deadline: now + 1.hour)
      expect(event.status_key(now: now)).to eq :upcoming
      expect(event.status_label(now: now)).to eq '開催予定'
    end
  end
end
