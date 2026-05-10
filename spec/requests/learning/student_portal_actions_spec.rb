require "rails_helper"

RSpec.describe "Learning student portal actions", type: :request do
  let!(:learning_domain) { Domain.find_or_create_by!(name: "learning") }
  let(:teacher) { create(:customer, domain_name: "learning", confirmed_at: Time.current) }
  let(:student) { create(:learning_student, customer: teacher, learning_school_group: school_group, email: email, nickname: "ギターさん") }
  let(:school_group) { create(:learning_school_group, customer: teacher, name: "軽音高校") }
  let(:email) { "student@example.com" }

  before { sign_in teacher }

  describe "POST /learning/students/:id/send_portal_mail" do
    it "メールアドレスがあれば生徒向けページを送信すること" do
      expect {
        post send_portal_mail_learning_student_path(student)
      }.to change(ActionMailer::Base.deliveries, :count).by(1)

      expect(response).to redirect_to(learning_student_path(student))
      expect(flash[:notice]).to eq("生徒向けページをメールで送信しました。")
    end

    context "メールアドレス未登録の場合" do
      let(:email) { nil }

      it "送信せずに分かりやすい警告を表示すること" do
        expect {
          post send_portal_mail_learning_student_path(student)
        }.not_to change(ActionMailer::Base.deliveries, :count)

        expect(response).to redirect_to(learning_student_path(student))
        expect(flash[:alert]).to eq("この生徒はメールアドレス未登録です。生徒情報を編集してから送信してください。")
      end
    end
  end

  describe "GET /learning/students/:id" do
    it "生徒ページ導線を表示し、URL文字列の大きな重複表示はしないこと" do
      get learning_student_path(student)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("生徒ページを見る")
      expect(response.body).to include("URLをコピー")
      expect(response.body).not_to include("生徒向けページURL")
    end
  end

  describe "GET /learning/portal/:token" do
    it "チュートリアルの次へボタンと完了先を表示すること" do
      get learning_student_portal_path(student.public_access_token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("次へ")
      expect(response.body).to include(learning_student_portal_complete_tutorial_path(student.public_access_token))
    end
  end
end
