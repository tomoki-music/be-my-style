require 'rails_helper'

RSpec.describe CustomerFeedback, type: :model do
  it "正常な投稿を保存できること" do
    feedback = build(:customer_feedback)
    expect(feedback).to be_valid
  end

  it "投稿者(customer)がなければ無効なこと" do
    feedback = build(:customer_feedback, customer: nil)
    expect(feedback).to be_invalid
  end

  it "categoryの初期値がnilであること（DBデフォルトを持たない）" do
    expect(CustomerFeedback.new.category).to be_nil
  end

  it "categoryを一度も指定していないモデルは保存できないこと" do
    feedback = CustomerFeedback.new(customer: create(:customer), body: "本文")
    expect(feedback.save).to be false
    expect(feedback.errors[:category]).to be_present
  end

  it "カテゴリーが必須なこと（明示的にnil）" do
    feedback = build(:customer_feedback, category: nil)
    expect(feedback).to be_invalid
    expect(feedback.errors[:category]).to be_present
  end

  it "正常なcategoryを指定すれば保存できること" do
    feedback = CustomerFeedback.new(customer: create(:customer), category: :consultation, body: "本文")
    expect(feedback.save).to be true
    expect(feedback.reload.category).to eq "consultation"
  end

  it "statusを指定しない場合はunreadで保存されること" do
    feedback = CustomerFeedback.new(customer: create(:customer), category: :other, body: "本文")
    feedback.save!
    expect(feedback.reload.status).to eq "unread"
  end

  it "DBスキーマ上、categoryにdefaultがなく、statusにはdefault 0があること" do
    expect(CustomerFeedback.columns_hash["category"].default).to be_nil
    expect(CustomerFeedback.columns_hash["status"].default).to eq "0"
  end

  it "内容が必須なこと" do
    feedback = build(:customer_feedback, body: "")
    expect(feedback).to be_invalid
    expect(feedback.errors[:body]).to be_present
  end

  it "カテゴリーの不正値を受け付けないこと" do
    expect { build(:customer_feedback, category: "unknown_category") }.to raise_error(ArgumentError)
  end

  it "件名は100文字以内であること" do
    expect(build(:customer_feedback, subject: "あ" * 100)).to be_valid
    expect(build(:customer_feedback, subject: "あ" * 101)).to be_invalid
  end

  it "内容は2,000文字以内であること" do
    expect(build(:customer_feedback, body: "あ" * 2000)).to be_valid
    expect(build(:customer_feedback, body: "あ" * 2001)).to be_invalid
  end

  it "statusの初期値がunreadであること" do
    expect(CustomerFeedback.new.status).to eq "unread"
  end

  it "投稿者と関連していること" do
    customer = create(:customer)
    feedback = create(:customer_feedback, customer: customer)
    expect(feedback.customer).to eq customer
    expect(customer.customer_feedbacks).to include(feedback)
  end

  it "退会済みユーザーの投稿でもcustomerを参照できること" do
    customer = create(:customer)
    feedback = create(:customer_feedback, customer: customer)
    customer.update!(is_deleted: true)
    expect(feedback.reload.customer).to eq customer
  end

  it "category_label / status_label が日本語を返すこと" do
    feedback = build(:customer_feedback, category: :bug_report, status: :reviewing)
    expect(feedback.category_label).to eq "アプリの不具合修正要望"
    expect(feedback.status_label).to eq "確認中"
  end
end
