require "rails_helper"

RSpec.describe "Learning onboarding success flow", type: :request do
  let!(:learning_domain) { Domain.find_or_create_by!(name: "learning") }
  let(:teacher) { create(:customer, domain_name: "learning", confirmed_at: Time.current) }

  describe "GET /learning/teacher_dashboard" do
    before { sign_in teacher }

    it "shows first-day setup guidance when learning data is not ready" do
      get learning_teacher_dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("使い方ナビ")
      expect(response.body).to include("生徒を登録しよう")
      expect(response.body).to include("初日セットアップ")
      expect(response.body).to include("生徒を登録する")
      expect(response.body).to include("今、声かけしたい生徒")
      expect(response.body).to include("今週のまとめ")
      expect(response.body).to include("今週の成長")
      expect(response.body).to include("まずは生徒を1人登録しましょう")
    end

    it "shows voice prompt templates for stagnant students" do
      student = create(:learning_student, customer: teacher, nickname: "ギターさん")
      create(:learning_progress_log, customer: teacher, learning_student: student,
                                    practiced_on: 3.days.ago.to_date)

      get learning_teacher_dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ギターさん")
      expect(response.body).to include("停滞中")
      expect(response.body).to include("最近どう？少しだけでもやってみよう！")
      expect(response.body).to include("コピー")
      expect(response.body).to include("通知ログを見る")
      expect(response.body).to include("通知設定：手動コピー")
      expect(response.body).to include("通知設定を変更")
      expect(response.body).to include("LINEで送る")
      expect(response.body).to include("メールで送る")
    end
  end

  describe "GET /learning/notifications" do
    before { sign_in teacher }

    it "shows generated notification candidates without persistence" do
      student = create(:learning_student, customer: teacher, nickname: "ギターさん")
      create(:learning_progress_log, customer: teacher, learning_student: student,
                                    practiced_on: 5.days.ago.to_date)

      get learning_notifications_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("通知ログ")
      expect(response.body).to include("ギターさん")
      expect(response.body).to include("5日")
      expect(response.body).to include("もう一度始めてみよう")
      expect(response.body).to include("先生から声かけして再スタートする")
    end
  end

  describe "GET /learning/portal/:token" do
    it "shows a reassuring empty state when no training is assigned" do
      student = create(:learning_student, customer: teacher, nickname: "ギターさん")

      get learning_student_portal_path(student.public_access_token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("先生が準備中です")
      expect(response.body).to include("7日間スタートガイド")
      expect(response.body).to include("今のあなたへの一言")
      expect(response.body).to include("まずは1つやってみよう！")
      expect(response.body).to include("継続バッジ")
      expect(response.body).to include("今週は0人が練習しています")
      expect(response.body).to include("課題は先生が準備中です")
    end

    it "points the student to the first unfinished training" do
      student = create(:learning_student, customer: teacher, nickname: "ギターさん")
      create(:learning_student_training, customer: teacher, learning_student: student, title: "コード練習")

      get learning_student_portal_path(student.public_access_token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("今日やること")
      expect(response.body).to include("コード練習")
      expect(response.body).to include("優先度")
      expect(response.body).to include("連続日数")
      expect(response.body).to include("今すぐやる")
      expect(response.body).to include("あなたにおすすめの練習")
    end

    it "shows a comeback message when the student has been idle for 3 days" do
      student = create(:learning_student, customer: teacher, nickname: "ギターさん")
      create(:learning_student_training, customer: teacher, learning_student: student, title: "コード練習")
      create(:learning_progress_log, customer: teacher, learning_student: student,
                                    practiced_on: 3.days.ago.to_date)

      get learning_student_portal_path(student.public_access_token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("おかえりなさい")
      expect(response.body).to include("ここから再スタートできます")
      expect(response.body).to include("最近少し空いています")
    end
  end
end
