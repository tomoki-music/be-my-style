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
end
