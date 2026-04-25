require 'rails_helper'

RSpec.describe 'Customerモデルのテスト', type: :model do
  let(:customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:other_customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:community) { FactoryBot.create(:community) }
  let(:activity) { FactoryBot.create(:activity, customer: customer) }
  let(:comment) { FactoryBot.create(:comment, customer: other_customer, activity: activity) }
  let(:event) { FactoryBot.create(:event, :event_with_songs, customer: customer) }

  describe 'バリデーションのテスト' do
    it '登録可能ドメインにsingingを含むこと' do
      expect(Customer::SIGN_UP_DOMAIN_NAMES).to include("music", "business", "learning", "singing")
    end

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
    context 'Favoriteモデルとの関係' do
      it 'favoriteと1:Nとなっている' do
        expect(Customer.reflect_on_association(:favorites).macro).to eq :has_many
      end
    end
    context 'Commentモデルとの関係' do
      it 'commentと1:Nとなっている' do
        expect(Customer.reflect_on_association(:comments).macro).to eq :has_many
      end
    end
    context 'Eventモデルとの関係' do
      it 'eventと1:Nとなっている' do
        expect(Customer.reflect_on_association(:events).macro).to eq :has_many
      end
    end
    context 'songモデルとの関係' do
      it 'songモデルと1:Nとなっている' do
        expect(Customer.reflect_on_association(:songs).macro).to eq :has_many
      end
      it '中間テーブルsong_customersと1:Nとなっている' do
        expect(Customer.reflect_on_association(:song_customers).macro).to eq :has_many
      end
    end
    context 'join_partモデルとの関係' do
      it 'join_partモデルと1:Nとなっている' do
        expect(Customer.reflect_on_association(:join_parts).macro).to eq :has_many
      end
      it '中間テーブルjoin_part_customersと1:Nとなっている' do
        expect(Customer.reflect_on_association(:join_part_customers).macro).to eq :has_many
      end
    end
    context 'Requestモデルとの関係' do
      it 'requestモデルと1:Nとなっている' do
        expect(Customer.reflect_on_association(:requests).macro).to eq :has_many
      end
    end
  end
  describe 'モデルのインスタンスメソッドのテスト' do
    context 'ドメイン判定メソッドのテスト' do
      let(:domain_customer) { FactoryBot.create(:customer, domain_name: "singing") }
      let!(:music_domain) { Domain.find_or_create_by!(name: "music") }
      let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
      let!(:learning_domain) { Domain.find_or_create_by!(name: "learning") }
      let!(:singing_domain) { Domain.find_or_create_by!(name: "singing") }

      it 'singing_user?がsingingドメインを判定できること' do
        CustomerDomain.find_or_create_by!(customer: domain_customer, domain: singing_domain)

        expect(domain_customer.singing_user?).to eq true
      end

      it '既存domainの判定が維持されること' do
        CustomerDomain.find_or_create_by!(customer: domain_customer, domain: music_domain)
        CustomerDomain.find_or_create_by!(customer: domain_customer, domain: business_domain)
        CustomerDomain.find_or_create_by!(customer: domain_customer, domain: learning_domain)

        expect(domain_customer.music_user?).to eq true
        expect(domain_customer.business_user?).to eq true
        expect(domain_customer.learning_user?).to eq true
      end
    end

    context '歌唱・演奏診断の月次回数制限' do
      it 'freeは月1回まで利用できること' do
        expect(customer.singing_diagnosis_monthly_limit).to eq 1
      end

      it 'lightは月5回まで利用できること' do
        customer.create_subscription!(status: "active", plan: "light")

        expect(customer.singing_diagnosis_monthly_limit).to eq 5
      end

      it 'coreは月20回まで利用できること' do
        customer.create_subscription!(status: "active", plan: "core")

        expect(customer.singing_diagnosis_monthly_limit).to eq 20
      end

      it 'premiumは無制限で利用できること' do
        customer.create_subscription!(status: "active", plan: "premium")

        expect(customer.singing_diagnosis_monthly_limit).to be_nil
        expect(customer.can_create_singing_diagnosis?).to eq true
      end

      it 'adminは無制限で利用できること' do
        customer.update!(is_owner: :admin)

        expect(customer.singing_diagnosis_monthly_limit).to be_nil
        expect(customer.can_create_singing_diagnosis?).to eq true
      end

      it '上限に達すると作成不可になること' do
        customer.create_subscription!(status: "active", plan: "light")
        FactoryBot.create_list(:singing_diagnosis, 5, customer: customer, status: :completed)

        expect(customer.remaining_singing_diagnosis_quota).to eq 0
        expect(customer.can_create_singing_diagnosis?).to eq false
      end

      it 'failedの診断は月次利用回数に含めないこと' do
        FactoryBot.create(:singing_diagnosis, customer: customer, status: :failed)

        expect(customer.monthly_singing_diagnosis_count).to eq 0
        expect(customer.remaining_singing_diagnosis_quota).to eq 1
        expect(customer.can_create_singing_diagnosis?).to eq true
      end

      it 'queuedとprocessingの診断は月次利用回数に含めないこと' do
        FactoryBot.create(:singing_diagnosis, customer: customer, status: :queued)
        FactoryBot.create(:singing_diagnosis, customer: customer, status: :processing)

        expect(customer.monthly_singing_diagnosis_count).to eq 0
        expect(customer.can_create_singing_diagnosis?).to eq true
      end

      it 'completedの診断だけ月次利用回数に含めること' do
        FactoryBot.create(:singing_diagnosis, customer: customer, status: :completed)
        FactoryBot.create(:singing_diagnosis, customer: customer, status: :failed)

        expect(customer.monthly_singing_diagnosis_count).to eq 1
        expect(customer.remaining_singing_diagnosis_quota).to eq 0
        expect(customer.can_create_singing_diagnosis?).to eq false
      end
    end

    context '歌唱・演奏診断の機能制御' do
      it 'FEATURE_RULESにsinging用のkeyを含むこと' do
        expect(Customer::FEATURE_RULES.keys).to include(
          :singing_diagnosis_history,
          :singing_diagnosis_comparison,
          :singing_diagnosis_advanced_feedback,
          :singing_diagnosis_priority,
          :singing_diagnosis_ai_comment
        )
      end

      it 'freeは履歴のみ利用対象になること' do
        expect(customer.has_feature?(:singing_diagnosis_history)).to eq true
        expect(customer.has_feature?(:singing_diagnosis_comparison)).to eq false
        expect(customer.has_feature?(:singing_diagnosis_advanced_feedback)).to eq false
        expect(customer.has_feature?(:singing_diagnosis_priority)).to eq false
      end

      it 'freeは個別チャットを利用できること' do
        expect(customer.has_feature?(:music_direct_chat)).to eq true
      end

      it 'lightは履歴比較まで利用対象になること' do
        customer.create_subscription!(status: "active", plan: "light")

        expect(customer.has_feature?(:singing_diagnosis_history)).to eq true
        expect(customer.has_feature?(:singing_diagnosis_comparison)).to eq true
        expect(customer.has_feature?(:singing_diagnosis_advanced_feedback)).to eq false
        expect(customer.has_feature?(:singing_diagnosis_priority)).to eq false
      end

      it 'coreは詳細フィードバックまで利用対象になること' do
        customer.create_subscription!(status: "active", plan: "core")

        expect(customer.has_feature?(:singing_diagnosis_history)).to eq true
        expect(customer.has_feature?(:singing_diagnosis_comparison)).to eq true
        expect(customer.has_feature?(:singing_diagnosis_advanced_feedback)).to eq true
        expect(customer.has_feature?(:singing_diagnosis_priority)).to eq false
      end

      it 'premiumは優先解析とAIコメントまで利用対象になること' do
        customer.create_subscription!(status: "active", plan: "premium")

        expect(customer.has_feature?(:singing_diagnosis_history)).to eq true
        expect(customer.has_feature?(:singing_diagnosis_comparison)).to eq true
        expect(customer.has_feature?(:singing_diagnosis_advanced_feedback)).to eq true
        expect(customer.has_feature?(:singing_diagnosis_priority)).to eq true
        expect(customer.has_feature?(:singing_diagnosis_ai_comment)).to eq true
      end

      it 'adminはsinging用の機能をすべて利用対象として扱うこと' do
        customer.update!(is_owner: :admin)

        expect(customer.has_feature?(:singing_diagnosis_history)).to eq true
        expect(customer.has_feature?(:singing_diagnosis_comparison)).to eq true
        expect(customer.has_feature?(:singing_diagnosis_advanced_feedback)).to eq true
        expect(customer.has_feature?(:singing_diagnosis_priority)).to eq true
        expect(customer.has_feature?(:singing_diagnosis_ai_comment)).to eq true
      end
    end

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
    context 'いいねの通知メソッドのテスト' do
      it 'いいねのインスタンスが作成される' do
        expect { other_customer.create_notification_favorite(customer, activity.id) }.to change(Notification, :count).by(1)
      end
    end
    context 'コメントの通知メソッドのテスト' do
      it 'コメントのインスタンスが作成される' do
        expect { other_customer.create_notification_comment(customer, activity.id) }.to change(Notification, :count).by(1)
      end
    end
    context 'リクエストの通知メソッドのテスト' do
      it 'リクエストのインスタンスが作成される' do
        expect { other_customer.create_notification_request_msg(customer, event.id) }.to change(Notification, :count).by(1)
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
    context '活動報告投稿の通知メソッドのテスト（フォローワー向け）' do
      it '通知のインスタンスが作成される' do
        expect { other_customer.create_notification_activity_for_follow(customer, activity.id) }.to change(Notification, :count).by(1)
      end
    end
    context '活動報告投稿の通知メソッドのテスト（コミュニティ向け）' do
      it '通知のインスタンスが作成される' do
        expect { other_customer.create_notification_activity_for_community(customer, activity.id, community.id) }.to change(Notification, :count).by(1)
      end
    end
    context 'イベント開催の通知メソッドのテスト（フォローワー向け）' do
      it '通知のインスタンスが作成される' do
        expect { other_customer.create_notification_event_for_follow(customer, event.id) }.to change(Notification, :count).by(1)
      end
    end
    context 'イベント開催の通知メソッドのテスト（コミュニティ向け）' do
      it '通知のインスタンスが作成される' do
        expect { other_customer.create_notification_event_for_community(customer, event.id, community.id) }.to change(Notification, :count).by(1)
      end
    end
    context 'イベント参加の通知メソッドのテスト' do
      it '通知のインスタンスが作成される' do
        expect { other_customer.create_notification_join_event(customer, event.id) }.to change(Notification, :count).by(1)
      end
    end
  end
end
