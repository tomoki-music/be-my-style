require "rails_helper"

RSpec.describe "Learning training masters", type: :request do
  let(:teacher) { create(:customer, domain_name: "learning", confirmed_at: Time.current) }

  before { sign_in teacher }

  it "作成フォームにチェック方法・達成の目安・確認者を表示すること" do
    get new_learning_training_master_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("チェック方法")
    expect(response.body).to include("達成基準")
    expect(response.body).to include("確認者")
    expect(response.body).to include("メトロノーム80で8小節止まらず演奏できるか確認")
    expect(response.body).to include("生徒同士で確認")
  end
end
