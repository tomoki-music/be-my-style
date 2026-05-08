require 'rails_helper'

RSpec.describe 'Notificationモデルのテスト', type: :model do
  describe 'アソシエーションのテスト' do
    context 'Customerモデルとの関係' do
      it 'visitorとN:1となっている' do
        expect(Notification.reflect_on_association(:visitor).macro).to eq :belongs_to
      end
      it 'visitedとN:1となっている' do
        expect(Notification.reflect_on_association(:visited).macro).to eq :belongs_to
      end
    end
  end

  describe 'Learning通知設計' do
    it '将来接続用の通知種別を定義している' do
      expect(Notification::LEARNING_ACTION_TYPES).to include(
        reminder: "learning_reminder",
        teacher_action: "learning_teacher_action",
        weekly_summary: "learning_weekly_summary"
      )
    end
  end
end
