require 'rails_helper'

RSpec.describe 'ログイン継続中のアクティビティ記録', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:customer) { create(:customer, :customer_with_parts) }

  describe 'ログイン済み Customer のリクエスト' do
    before { sign_in customer }

    it 'GET すると last_active_at が更新される' do
      expect { get public_customer_path(customer) }
        .to change { customer.reload.last_active_at }.from(nil)
      expect(response).to have_http_status(:ok)
    end

    it 'PATCH（更新系リクエスト）でも last_active_at が更新される' do
      expect do
        patch public_customer_path(customer), params: { customer: { introduction: '更新テスト' } }
      end.to change { customer.reload.last_active_at }.from(nil)
    end

    it 'Ajax／JS 形式（JSON を返す操作）でも last_active_at が更新される' do
      activity = create(:activity, customer: customer)

      expect do
        post public_activity_reactions_path(activity),
             params: { reaction_type: 'fire' },
             headers: { 'X-Requested-With' => 'XMLHttpRequest' }
      end.to change { customer.reload.last_active_at }.from(nil)
      expect(response).to have_http_status(:ok)
    end

    it '15分以内の連続リクエストでは last_active_at が変わらない' do
      travel_to(Time.zone.local(2026, 8, 27, 12, 0, 0)) do
        get public_customer_path(customer)
      end
      first_value = customer.reload.last_active_at

      travel_to(Time.zone.local(2026, 8, 27, 12, 10, 0)) do
        get public_customer_path(customer)
      end

      expect(customer.reload.last_active_at).to eq first_value
    end

    it 'HEAD では更新されない' do
      head public_customer_path(customer)

      expect(customer.reload.last_active_at).to be_nil
    end

    it '正確な last_active_at がレスポンス本文へ表示されない' do
      travel_to(Time.zone.local(2026, 8, 27, 12, 34, 56)) do
        get public_customer_path(customer)
      end

      value = customer.reload.last_active_at
      expect(response.body).not_to include('last_active_at')
      expect(response.body).not_to include(value.strftime('%Y/%m/%d %H:%M'))
      expect(response.body).not_to include(value.iso8601)
    end
  end

  describe '対象外のアクセス' do
    it '未ログインアクセスでは更新されない' do
      get public_customer_path(customer)

      expect(customer.reload.last_active_at).to be_nil
    end

    it 'Customer とは別の Admin 認証だけでは更新されない' do
      admin = create(:admin)
      sign_in admin

      get admin_events_path

      expect(response).to have_http_status(:ok)
      expect(customer.reload.last_active_at).to be_nil
      expect(Customer.where.not(last_active_at: nil)).to be_empty
    end
  end

  describe 'ActivityTracker が失敗した場合' do
    before { sign_in customer }

    it 'StandardError が発生しても通常レスポンスが維持され、警告ログが出る' do
      allow(Customers::ActivityTracker).to receive(:touch)
        .and_raise(StandardError, 'boom')
      expect(Rails.logger).to receive(:warn).with(/\[CustomerActivity\] failed/)

      get public_customer_path(customer)

      expect(response).to have_http_status(:ok)
    end
  end
end
