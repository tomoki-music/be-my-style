require "rails_helper"

RSpec.describe LearningAssignmentReviewHistory, type: :model do
  let!(:learning_domain) { Domain.find_or_create_by!(name: "learning") }
  let(:teacher) { create(:customer, domain_name: "learning", confirmed_at: Time.current) }
  let(:assignment) { create(:learning_assignment, customer: teacher) }

  describe "バリデーション" do
    it "actionがsubmittedで有効なこと" do
      history = assignment.review_histories.build(action: "submitted")
      expect(history).to be_valid
    end

    it "actionがapprovedで有効なこと" do
      history = assignment.review_histories.build(action: "approved")
      expect(history).to be_valid
    end

    it "actionがrevision_requestedで有効なこと" do
      history = assignment.review_histories.build(action: "revision_requested")
      expect(history).to be_valid
    end

    it "無効なactionは保存できないこと" do
      history = assignment.review_histories.build(action: "invalid_action")
      expect(history).not_to be_valid
      expect(history.errors[:action]).to be_present
    end

    it "actionが空の場合は保存できないこと" do
      history = assignment.review_histories.build(action: nil)
      expect(history).not_to be_valid
    end
  end

  describe "スコープ" do
    it "chronologicalで古い順に並ぶこと" do
      old = assignment.review_histories.create!(action: "submitted", created_at: 2.hours.ago)
      new_history = assignment.review_histories.create!(action: "revision_requested", created_at: 1.hour.ago)

      result = assignment.review_histories.chronological.to_a
      expect(result.first).to eq(old)
      expect(result.last).to eq(new_history)
    end

    it "reverse_chronologicalで新しい順に並ぶこと" do
      old = assignment.review_histories.create!(action: "submitted", created_at: 2.hours.ago)
      new_history = assignment.review_histories.create!(action: "approved", created_at: 1.hour.ago)

      result = assignment.review_histories.reverse_chronological.to_a
      expect(result.first).to eq(new_history)
      expect(result.last).to eq(old)
    end
  end

  describe "action_label" do
    it "submittedは生徒が提出と返すこと" do
      history = build(:learning_assignment_review_history, action: "submitted")
      expect(history.action_label).to eq("生徒が提出")
    end

    it "approvedは先生が承認と返すこと" do
      history = build(:learning_assignment_review_history, action: "approved")
      expect(history.action_label).to eq("先生が承認")
    end

    it "revision_requestedは先生が差し戻しと返すこと" do
      history = build(:learning_assignment_review_history, action: "revision_requested")
      expect(history.action_label).to eq("先生が差し戻し")
    end
  end

  describe "reviewer保存" do
    it "reviewerが保存されること" do
      history = assignment.review_histories.create!(action: "approved", reviewer: teacher)
      expect(history.reload.reviewer).to eq(teacher)
    end

    it "reviewerはnilでも保存できること" do
      history = assignment.review_histories.create!(action: "submitted")
      expect(history.reload.reviewer).to be_nil
    end
  end

  describe "comment保存" do
    it "コメントが保存されること" do
      history = assignment.review_histories.create!(action: "revision_requested", comment: "テンポを確認してみよう")
      expect(history.reload.comment).to eq("テンポを確認してみよう")
    end
  end
end
