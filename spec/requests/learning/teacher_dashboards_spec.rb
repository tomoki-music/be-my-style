require "rails_helper"

RSpec.describe "Learning teacher dashboards", type: :request do
  let(:teacher) { create(:customer, domain_name: "learning", confirmed_at: Time.current) }

  before { sign_in teacher }

  it "shows the first setup checklist" do
    get learning_teacher_dashboard_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("まずは3ステップで始めましょう")
    expect(response.body).to include("初回設定チェックリスト")
    expect(response.body).to include("生徒を登録する")
    expect(response.body).to include("LINE連携QRを配布する")
    expect(response.body).to include("通知テンプレートを確認する")
    expect(response.body).to include("課題を1つ作成する")
    expect(response.body).to include("自動リマインドをプレビューする")
    expect(response.body).to include("ONにしない限り自動送信されないので安心です")
  end

  it "先生確認が必要な未完了トレーニングを表示すること" do
    student = create(:learning_student, customer: teacher)
    master = create(:learning_training_master,
                    customer: teacher,
                    check_method: "8小節を止まらず演奏できるか確認",
                    achievement_criteria: "テンポを崩さず最後までできたら達成",
                    judge_type: "teacher")
    create(:learning_student_training,
           customer: teacher,
           learning_student: student,
           learning_training_master: master,
           title: nil)

    get learning_teacher_dashboard_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("先生が確認するトレーニング")
    expect(response.body).to include("先生確認が必要")
    expect(response.body).to include("8小節を止まらず演奏できるか確認")
  end

  it "承認待ちの先生確認課題を表示すること" do
    student = create(:learning_student, customer: teacher)
    master = create(:learning_training_master,
                    customer: teacher,
                    check_method: "8小節を止まらず演奏できるか確認",
                    achievement_criteria: "テンポを崩さず最後までできたら達成",
                    judge_type: "teacher")
    training = create(:learning_student_training,
                      customer: teacher,
                      learning_student: student,
                      learning_training_master: master,
                      title: nil)
    assignment = training.learning_assignments.first
    assignment.update!(status: "pending_review", submitted_at: Time.current)

    get learning_teacher_dashboard_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("先生確認待ち")
    expect(response.body).to include(student.display_name)
    expect(response.body).to include("承認")
    expect(response.body).to include("差し戻し")
    expect(response.body).to include("改善コメントを書く例")
    expect(response.body).to include("テンポを崩さず最後までできたら達成")
  end
end
