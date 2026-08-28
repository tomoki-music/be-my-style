require 'rails_helper'

RSpec.describe Customers::ActivityTracker, type: :service do
  include ActiveSupport::Testing::TimeHelpers

  let(:now) { Time.zone.local(2026, 8, 27, 12, 0, 0) }

  around do |example|
    travel_to(now) { example.run }
  end

  def sql_count(&block)
    count = 0
    counter = ->(*, payload) { count += 1 if payload[:sql].to_s.match?(/\A(SELECT|UPDATE)/i) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end

  describe '.touch' do
    let(:customer) { create(:customer) }

    it 'last_active_at が nil なら現在時刻へ更新する' do
      customer.update_column(:last_active_at, nil)

      described_class.touch(customer, now: now)

      expect(customer.last_active_at).to eq now
      expect(customer.reload.last_active_at).to eq now
    end

    it '15分より前なら更新する' do
      customer.update_column(:last_active_at, now - 16.minutes)

      described_class.touch(customer, now: now)

      expect(customer.reload.last_active_at).to eq now
    end

    it 'ちょうど15分前なら更新する' do
      customer.update_column(:last_active_at, now - 15.minutes)

      described_class.touch(customer, now: now)

      expect(customer.reload.last_active_at).to eq now
    end

    it '15分以内なら更新しない（追加SQLも発行しない）' do
      recent = now - 5.minutes
      customer.update_column(:last_active_at, recent)

      queries = sql_count { described_class.touch(customer, now: now) }

      expect(queries).to eq 0
      expect(customer.last_active_at).to eq recent
      expect(customer.reload.last_active_at).to eq recent
    end

    it '退会ユーザーは更新しない' do
      customer.update_columns(is_deleted: true, last_active_at: nil)

      queries = sql_count { described_class.touch(customer, now: now) }

      expect(queries).to eq 0
      expect(customer.reload.last_active_at).to be_nil
    end

    it 'nil を渡しても例外にならず、何もしない' do
      expect { described_class.touch(nil, now: now) }.not_to raise_error
    end

    it 'バリデーションを通さずに更新する' do
      customer.update_columns(name: '', last_active_at: nil)

      described_class.touch(customer, now: now)

      expect(customer.reload.last_active_at).to eq now
    end

    it 'updated_at を変更しない' do
      customer.update_columns(last_active_at: nil, updated_at: now - 3.days)
      original_updated_at = customer.reload.updated_at

      described_class.touch(customer, now: now)

      expect(customer.reload.updated_at).to eq original_updated_at
    end

    it 'DB で0件更新の場合、メモリ上の日時を誤って更新しない' do
      # 別プロセスが直前に更新した状況を模して、DB 側だけ新しい値にしておく。
      customer.update_column(:last_active_at, now - 20.minutes)
      stale_in_memory = customer.last_active_at
      Customer.where(id: customer.id).update_all(last_active_at: now - 1.minute)

      described_class.touch(customer, now: now)

      expect(customer.last_active_at).to eq stale_in_memory
      expect(customer.reload.last_active_at).to eq(now - 1.minute)
    end

    it '複数回呼び出しても15分以内は2回目以降更新しない' do
      customer.update_column(:last_active_at, nil)

      described_class.touch(customer, now: now)
      first_value = customer.last_active_at

      queries = sql_count { described_class.touch(customer, now: now + 10.minutes) }

      expect(queries).to eq 0
      expect(customer.last_active_at).to eq first_value
    end
  end
end
