require 'rails_helper'

RSpec.describe "Admin::CustomerFeedbacks", type: :request do
  let(:admin) { create(:admin) }
  let(:customer) { create(:customer) }
  let!(:feedback) { create(:customer_feedback, customer: customer, subject: "改善要望", body: "本文です") }

  describe "一般ユーザー / 未ログイン" do
    it "未ログインでは一覧にアクセスできないこと" do
      get admin_customer_feedbacks_path
      expect(response).to redirect_to(new_admin_session_path)
    end

    it "一般ユーザー(Customer)ではアクセスできないこと" do
      sign_in customer
      get admin_customer_feedbacks_path
      expect(response).to redirect_to(new_admin_session_path)
    end
  end

  describe "管理者ログイン済み" do
    before { sign_in admin }

    it "一覧を表示できること（新着順）" do
      old_feedback = create(:customer_feedback, customer: customer, subject: "古い投稿", created_at: 3.days.ago)
      new_feedback = create(:customer_feedback, customer: customer, subject: "新しい投稿", created_at: 1.minute.ago)

      get admin_customer_feedbacks_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("改善要望")
      expect(response.body.index("新しい投稿")).to be < response.body.index("古い投稿")
    end

    it "未確認件数が表示されること" do
      get admin_customer_feedbacks_path
      expect(response.body).to include("未確認")
    end

    it "カテゴリー・対応状況で絞り込めること" do
      bug = create(:customer_feedback, customer: customer, category: :bug_report, subject: "バグ報告")
      get admin_customer_feedbacks_path, params: { category: "bug_report" }
      expect(response.body).to include("バグ報告")
      expect(response.body).not_to include("改善要望")
      expect(bug).to be_present
    end

    it "詳細を表示できること" do
      get admin_customer_feedback_path(feedback)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("本文です")
      expect(response.body).to include(customer.name)
    end

    it "status と admin_note を更新できること" do
      patch admin_customer_feedback_path(feedback), params: {
        customer_feedback: { status: "reviewing", admin_note: "対応検討中" }
      }
      expect(response).to redirect_to(admin_customer_feedback_path(feedback))
      feedback.reload
      expect(feedback.status).to eq "reviewing"
      expect(feedback.admin_note).to eq "対応検討中"
    end

    it "投稿者が退会済みでも詳細がエラーにならないこと" do
      customer.update!(is_deleted: true)
      get admin_customer_feedback_path(feedback)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("退会済み")
    end

    it "本文のHTML/scriptがエスケープされること" do
      xss = create(:customer_feedback, customer: customer, body: "<script>alert(1)</script>")
      get admin_customer_feedback_path(xss)
      expect(response.body).not_to include("<script>alert(1)</script>")
    end

    def count_unread_count_queries
      queries = []
      callback = lambda do |*, payload|
        sql = payload[:sql].to_s
        queries << sql if sql.match?(/SELECT COUNT\(\*\).+customer_feedbacks.+status/i) && !sql.match?(/SCHEMA/)
      end
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
      queries
    end

    it "詳細画面：未確認件数COUNTが1リクエストにつき1回だけ実行されること（PC/スマホメニューで重複しない）" do
      create_list(:customer_feedback, 2, customer: customer, status: :unread)
      queries = count_unread_count_queries { get admin_customer_feedback_path(feedback) }
      expect(queries.size).to eq 1
    end

    it "一覧画面：メニューとヘッダの2箇所で表示しても未確認件数COUNTは1回だけであること" do
      create_list(:customer_feedback, 2, customer: customer, status: :unread)
      queries = count_unread_count_queries { get admin_customer_feedbacks_path }
      expect(queries.size).to eq 1
    end
  end
end
