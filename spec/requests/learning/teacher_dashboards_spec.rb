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

  it "差し戻し履歴がある課題には差し戻し回数と前回コメントを表示すること" do
    student = create(:learning_student, customer: teacher)
    master = create(:learning_training_master,
                    customer: teacher,
                    judge_type: "teacher")
    training = create(:learning_student_training,
                      customer: teacher,
                      learning_student: student,
                      learning_training_master: master,
                      title: nil)
    assignment = training.learning_assignments.first
    assignment.update!(status: "pending_review", submitted_at: Time.current)
    assignment.review_histories.create!(action: "revision_requested",
                                        reviewer: teacher,
                                        comment: "テンポを80に合わせてみよう")

    get learning_teacher_dashboard_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("差し戻し 1回")
    expect(response.body).to include("テンポを80に合わせてみよう")
  end

  it "他顧問の履歴は表示されないこと" do
    other_teacher = create(:customer, domain_name: "learning", confirmed_at: Time.current)
    other_student = create(:learning_student, customer: other_teacher)
    other_master = create(:learning_training_master, customer: other_teacher, judge_type: "teacher")
    other_training = create(:learning_student_training,
                            customer: other_teacher,
                            learning_student: other_student,
                            learning_training_master: other_master,
                            title: nil)
    other_assignment = other_training.learning_assignments.first
    other_assignment.update!(status: "pending_review", submitted_at: Time.current)
    other_assignment.review_histories.create!(action: "revision_requested",
                                              reviewer: other_teacher,
                                              comment: "他顧問のコメント")

    get learning_teacher_dashboard_path

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("他顧問のコメント")
  end

  it "差し戻し履歴がない場合に空状態UIを表示すること" do
    get learning_teacher_dashboard_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("指導改善ヒント")
    expect(response.body).to include("まだ差し戻し履歴はありません")
  end

  it "差し戻し履歴がある場合に分析UIを表示すること" do
    student = create(:learning_student, customer: teacher)
    master = create(:learning_training_master,
                    customer: teacher,
                    title: "メトロノーム練習",
                    judge_type: "teacher")
    training = create(:learning_student_training,
                      customer: teacher,
                      learning_student: student,
                      learning_training_master: master,
                      title: nil)
    assignment = training.learning_assignments.first
    assignment.review_histories.create!(action: "revision_requested",
                                        reviewer: teacher,
                                        comment: "テンポを意識してみよう")

    get learning_teacher_dashboard_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("指導改善ヒント")
    expect(response.body).to include("重点フォロー候補のトレーニング")
    expect(response.body).to include("メトロノーム練習")
    expect(response.body).to include("重点フォロー候補の生徒")
    expect(response.body).to include(student.display_name)
    expect(response.body).to include("最近の差し戻しコメント")
    expect(response.body).to include("テンポを意識してみよう")
  end

  it "他顧問の差し戻し分析は表示されないこと" do
    other_teacher2 = create(:customer, domain_name: "learning", confirmed_at: Time.current)
    other_student2 = create(:learning_student, customer: other_teacher2)
    other_master2 = create(:learning_training_master, customer: other_teacher2,
                                                       title: "他顧問のトレーニング",
                                                       judge_type: "teacher")
    other_training2 = create(:learning_student_training,
                              customer: other_teacher2,
                              learning_student: other_student2,
                              learning_training_master: other_master2,
                              title: nil)
    other_assignment2 = other_training2.learning_assignments.first
    other_assignment2.review_histories.create!(action: "revision_requested",
                                               reviewer: other_teacher2,
                                               comment: "他顧問のコメント分析")

    get learning_teacher_dashboard_path

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("他顧問のトレーニング")
    expect(response.body).not_to include("他顧問のコメント分析")
    expect(response.body).to include("まだ差し戻し履歴はありません")
  end
end
