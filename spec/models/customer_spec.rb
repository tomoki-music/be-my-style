require 'rails_helper'

RSpec.describe 'Customerモデルのテスト', type: :model do
  let(:customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:other_customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:community) { FactoryBot.create(:community) }

  describe 'バリデーションのテスト' do
    context 'nameカラムが不正' do
      it '空欄でないこと' do
        customer.name = ''
        expect(customer.valid?).to eq false
      end
      it '20文字以下であること' do
        customer.name = Faker::Lorem.characters(number:21)
        expect(customer.valid?).to eq false
      end
    end
    context 'emailカラムが不正' do
      it '空欄でないこと' do
        customer.email = ''
        expect(customer.valid?).to eq false
      end
      it '一意性のあるメールアドレスである事' do
        customer.email = other_customer.email
        expect(customer.valid?).to eq false
      end
    end
  end
  describe 'アソシエーションのテスト' do
    context 'Relationshipモデルとの関係' do
      it 'followingsと1:Nとなっている' do
        expect(Customer.reflect_on_association(:followings).macro).to eq :has_many
      end
      it 'followersと1:Nとなっている' do
        expect(Customer.reflect_on_association(:followers).macro).to eq :has_many
      end
    end
    context 'Notificationモデルとの関係' do
      it 'active_notificationsと1:Nとなっている' do
        expect(Customer.reflect_on_association(:active_notifications).macro).to eq :has_many
      end
      it 'passive_notificationsと1:Nとなっている' do
        expect(Customer.reflect_on_association(:passive_notifications).macro).to eq :has_many
      end
    end
    context 'chat_roomモデルとの関係' do
      it 'chat_roomとの中間テーブルと1:Nとなっている' do
        expect(Customer.reflect_on_association(:chat_room_customers).macro).to eq :has_many
      end
      it 'chat_roomと1:Nとなっている' do
        expect(Customer.reflect_on_association(:chat_rooms).macro).to eq :has_many
      end
      it 'communityと1:Nとなっている' do
        expect(Customer.reflect_on_association(:communities).macro).to eq :has_many
      end
    end
    context 'chat_messageモデルとの関係' do
      it 'chat_messageと1:Nとなっている' do
        expect(Customer.reflect_on_association(:chat_messages).macro).to eq :has_many
      end
    end
    context 'communityモデルとの関係' do
      it 'communityモデルと1:Nとなっている' do
        expect(Customer.reflect_on_association(:communities).macro).to eq :has_many
      end
      it '中間テーブルcommunity_customersと1:Nとなっている' do
        expect(Customer.reflect_on_association(:community_customers).macro).to eq :has_many
      end
    end
    context 'Permitモデルとの関係' do
      it 'permitと1:Nとなっている' do
        expect(Customer.reflect_on_association(:permits).macro).to eq :has_many
      end
    end
    context 'Activityモデルとの関係' do
      it 'activityと1:Nとなっている' do
        expect(Customer.reflect_on_association(:activities).macro).to eq :has_many
      end
    end
  end
  describe 'モデルのインスタンスメソッドのテスト' do
    context 'フォロー、アンフォローのメソッドテスト' do
      it 'フォローする' do
        expect(customer.follow(other_customer.id)).to be_valid
      end
      it 'フォローを外す' do
        customer.follow(other_customer.id)
        expect(customer.unfollow(other_customer.id)).to be_valid
      end
      it 'フォローしているかチェックする' do
        customer.follow(other_customer.id)
        expect(customer.following?(other_customer)).to eq true
      end
    end
    context 'フォローの通知メソッドのテスト' do
      it '通知のインスタンスが作成される' do
        expect { other_customer.create_notification_follow(customer) }.to change(Notification, :count).by(1)
      end
    end
    context 'チャットの通知メソッドのテスト' do
      it '通知のインスタンスが作成される' do
        expect { other_customer.create_notification_chat(customer) }.to change(Notification, :count).by(1)
      end
    end
    context 'コミュニティ参加申請の通知メソッドのテスト' do
      it '通知のインスタンスが作成される' do
        expect { other_customer.create_notification_request(customer, community) }.to change(Notification, :count).by(1)
      end
    end
    context 'コミュニティ参加申請のキャンセル通知メソッドのテスト' do
      it '通知のインスタンスが作成される' do
        expect { other_customer.create_notification_request_cancel(customer, community) }.to change(Notification, :count).by(1)
      end
    end
    context 'コミュニティ参加申請の許可の通知メソッドのテスト' do
      it '通知のインスタンスが作成される' do
        expect { other_customer.create_notification_accept(customer, community) }.to change(Notification, :count).by(1)
      end
    end
    context 'コミュニティ退会の通知メソッドのテスト' do
      it '通知のインスタンスが作成される' do
        expect { other_customer.create_notification_leave(customer, community) }.to change(Notification, :count).by(1)
      end
    end
  end
end
