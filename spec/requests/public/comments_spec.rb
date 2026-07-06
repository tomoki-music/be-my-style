require 'rails_helper'

RSpec.describe "Public::Comments", type: :request do
  let(:customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:other_customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:some_customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:activity) { FactoryBot.create(:activity, customer_id: customer.id) }
  let(:comment) { FactoryBot.create(:comment, customer_id: customer.id, activity_id: activity.id) }

  describe 'ログイン済み' do
    before do
      sign_in customer
      get public_activity_path(activity)
    end
    context "コメント(create)が正しく処理され登録される" do
      it "コメントの作成が成功する" do
        expect do
          post public_activity_comments_path(activity_id: activity.id), params: {
            comment: {
              comment: "MMM最高！",
            }
          }, xhr: true
        end.to change(Comment, :count).by(1)
      end

      it "3000文字の長文コメントでも500にならず投稿できる" do
        long_text = "あ" * 3000
        expect do
          post public_activity_comments_path(activity_id: activity.id), params: {
            comment: {
              comment: long_text,
            }
          }, xhr: true
        end.to change(Comment, :count).by(1)
        expect(response.status).to eq 200
        expect(Comment.last.comment.length).to eq 3000
      end

      it "スタンプのみの投稿が成功する" do
        expect do
          post public_activity_comments_path(activity_id: activity.id), params: {
            comment: {
              stamp_type: "fire",
            }
          }, xhr: true
        end.to change(Comment, :count).by(1)
        expect(response.status).to eq 200
      end

      it "3000文字を超えるコメントは500にならずエラーになる" do
        too_long = "あ" * 3001
        expect do
          post public_activity_comments_path(activity_id: activity.id), params: {
            comment: {
              comment: too_long,
            }
          }, xhr: true
        end.not_to change(Comment, :count)
        expect(response.status).to eq 200
        expect(flash[:alert]).to include("3000文字以内")
      end

      it "空コメント・スタンプなしは500にならずエラーになる" do
        expect do
          post public_activity_comments_path(activity_id: activity.id), params: {
            comment: {
              comment: "",
            }
          }, xhr: true
        end.not_to change(Comment, :count)
        expect(response.status).to eq 200
        expect(flash[:alert]).to include("コメントを入力してください")
      end
    end
    context "コメントを正しく削除(destroy)できる" do
      before do
        comment
      end
      it '正しく削除できる（投稿者本人である場合）' do
        expect do
          delete public_activity_comment_path(activity_id: activity.id, id: comment.id), xhr: true
        end.to change(Comment, :count).by(-1)
      end
    end
    context "コメントを正しく削除(destroy)できない" do
      before do
        sign_in some_customer
      end
      it 'リクエストは302 Foundとなること（投稿者本人でない場合）' do
        delete public_activity_comment_path(activity_id: activity.id, id: comment.id)
        expect(response.status).to eq 302
      end
    end
  end

  describe '非ログイン' do

  end
end
