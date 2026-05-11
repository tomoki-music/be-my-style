require "rails_helper"

RSpec.describe "Learning line message templates", type: :request do
  let!(:learning_domain) { Domain.find_or_create_by!(name: "learning") }
  let(:teacher) { create(:customer, domain_name: "learning", confirmed_at: Time.current) }

  before { sign_in teacher }

  it "テンプレートを作成して一覧に表示できること" do
    expect {
      post learning_line_message_templates_path,
           params: {
             learning_line_message_template: {
               title: "ライブ前",
               category: "event",
               body: "ライブまであと少し！1日5分でも積み重ねると変わるよ🔥",
               active: "1"
             }
           }
    }.to change(LearningLineMessageTemplate, :count).by(1)

    follow_redirect!

    expect(response.body).to include("ライブ前")
    expect(response.body).to include("1日5分")
  end

  it "他顧問のテンプレートは見えないこと" do
    other_teacher = create(:customer, domain_name: "learning", confirmed_at: Time.current)
    create(:learning_line_message_template, customer: other_teacher, title: "他顧問テンプレ")
    create(:learning_line_message_template, customer: teacher, title: "自分のテンプレ")

    get learning_line_message_templates_path

    expect(response.body).to include("自分のテンプレ")
    expect(response.body).not_to include("他顧問テンプレ")
  end

  it "他顧問のテンプレートは編集できないこと" do
    other_teacher = create(:customer, domain_name: "learning", confirmed_at: Time.current)
    template = create(:learning_line_message_template, customer: other_teacher)

    expect {
      patch learning_line_message_template_path(template),
            params: { learning_line_message_template: { title: "変更", category: "custom", body: "変更", active: "1" } }
    }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "送信画面にテンプレート本文をJS反映用dataとして出すこと" do
    create(:learning_line_message_template, customer: teacher, title: "未提出", category: "assignment", body: "課題の提出がまだ確認できていません！")

    get learning_students_path

    expect(response.body).to include("テンプレ選択")
    expect(response.body).to include("data-template-body")
    expect(response.body).to include("課題の提出がまだ確認できていません！")
  end
end
