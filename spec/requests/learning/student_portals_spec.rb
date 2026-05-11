require "rails_helper"

RSpec.describe "Learning student portals", type: :request do
  let(:teacher) { create(:customer, domain_name: "learning", confirmed_at: Time.current) }
  let(:student) { create(:learning_student, customer: teacher, tutorial_completed: true) }

  it "今週やることに確認方法・達成の目安・確認者を表示すること" do
    master = create(:learning_training_master,
                    customer: teacher,
                    check_method: "メトロノーム80で8小節止まらず演奏できるか確認",
                    achievement_criteria: "3回中2回、テンポを崩さず最後まで演奏できたら達成",
                    judge_type: "peer")
    create(:learning_student_training,
           customer: teacher,
           learning_student: student,
           learning_training_master: master,
           title: nil)

    get learning_student_portal_path(student.public_access_token)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("確認方法")
    expect(response.body).to include("メトロノーム80で8小節止まらず演奏できるか確認")
    expect(response.body).to include("達成の目安")
    expect(response.body).to include("3回中2回、テンポを崩さず最後まで演奏できたら達成")
    expect(response.body).to include("誰に見てもらうか")
    expect(response.body).to include("生徒同士で確認")
  end

  it "差し戻し課題を今週やることに再チャレンジとして表示すること" do
    training = create(:learning_student_training,
                      customer: teacher,
                      learning_student: student)
    assignment = training.learning_assignments.first
    assignment.update!(
      status: "needs_revision",
      reviewed_at: Time.current,
      review_comment: "テンポ80で再チャレンジしてみよう"
    )

    get learning_student_portal_path(student.public_access_token)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("もう一度チャレンジ！")
    expect(response.body).to include("先生からのコメント")
    expect(response.body).to include("テンポ80で再チャレンジしてみよう")
    expect(response.body).to include("できたらLINEで「やった」と返信しよう")
  end
end
