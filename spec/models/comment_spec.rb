require 'rails_helper'

RSpec.describe Comment, type: :model do
  let(:customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:other_customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:some_customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:activity) { FactoryBot.create(:activity, customer_id: customer.id) }
  let(:comment) { FactoryBot.create(:comment, customer_id: other_customer.id, activity_id: activity.id) }

  describe 'コメントの投稿テスト' do
    context 'コメント投稿できる場合' do
      it 'コメント入力済みあれば投稿できる' do
        expect(comment).to be_valid
      end
    end

    context '投稿できない場合' do
      it 'コメントが空では投稿できない' do
        comment.comment = ''
        expect(comment).to be_invalid
      end

      it '3000文字を超えるコメントは投稿できない' do
        comment.comment = "あ" * 3001
        expect(comment).to be_invalid
      end
    end

    context '長文・スタンプコメントの場合' do
      it '3000文字ちょうどのコメントは投稿できる' do
        comment.comment = "あ" * 3000
        expect(comment).to be_valid
      end

      it 'コメント本文が空でもスタンプがあれば投稿できる' do
        comment.comment = ''
        comment.stamp_type = 'fire'
        expect(comment).to be_valid
      end
    end
  end

  describe 'アソシエーションのテスト' do
    context 'コメント機能について' do
      it 'customersと1:Nとなっている' do
        expect(Comment.reflect_on_association(:customer).macro).to eq :belongs_to
      end
      it 'activitiesと1:Nとなっている' do
        expect(Comment.reflect_on_association(:activity).macro).to eq :belongs_to
      end
    end
  end
end
