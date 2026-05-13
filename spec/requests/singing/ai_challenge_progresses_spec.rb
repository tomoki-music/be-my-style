require "rails_helper"

RSpec.describe "Singing::AiChallengeProgresses", type: :request do
  let(:singing_customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let(:other_customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let!(:singing_domain) { Domain.find_or_create_by!(name: "singing") }

  before do
    CustomerDomain.find_or_create_by!(customer: singing_customer, domain: singing_domain)
    CustomerDomain.find_or_create_by!(customer: other_customer, domain: singing_domain)
  end

  def create_monthly_challenge_diagnoses(customer)
    FactoryBot.create(
      :singing_diagnosis,
      customer: customer,
      status: :completed,
      created_at: 1.month.ago,
      overall_score: 75,
      pitch_score: 70,
      rhythm_score: 70,
      expression_score: 70
    )
    FactoryBot.create(
      :singing_diagnosis,
      customer: customer,
      status: :completed,
      overall_score: 85,
      pitch_score: 85,
      rhythm_score: 60,
      expression_score: 80
    )
  end

  describe "PATCH /singing/ai_challenge_progress" do
    it "Coreユーザーはprogressを更新できること" do
      singing_customer.create_subscription!(status: "active", plan: "core")
      diagnosis = create_monthly_challenge_diagnoses(singing_customer)
      sign_in singing_customer

      patch singing_ai_challenge_progress_path, params: {
        diagnosis_id: diagnosis.id,
        singing_ai_challenge_progress: {
          tried: "1",
          completed: "1",
          next_diagnosis_planned: "0"
        }
      }

      expect(response).to redirect_to(singing_diagnosis_path(diagnosis))
      progress = singing_customer.singing_ai_challenge_progresses.find_by!(target_key: "rhythm")
      expect(progress.tried).to eq true
      expect(progress.completed).to eq true
      expect(progress.next_diagnosis_planned).to eq false
      expect(progress.completed_at).to be_present
    end

    it "Premiumユーザーはprogressを更新できること" do
      singing_customer.create_subscription!(status: "active", plan: "premium")
      diagnosis = create_monthly_challenge_diagnoses(singing_customer)
      sign_in singing_customer

      patch singing_ai_challenge_progress_path, params: {
        diagnosis_id: diagnosis.id,
        singing_ai_challenge_progress: {
          tried: "1",
          completed: "0",
          next_diagnosis_planned: "1"
        }
      }

      expect(response).to redirect_to(singing_diagnosis_path(diagnosis))
      progress = singing_customer.singing_ai_challenge_progresses.find_by!(target_key: "rhythm")
      expect(progress.tried).to eq true
      expect(progress.completed).to eq false
      expect(progress.next_diagnosis_planned).to eq true
    end

    it "Freeユーザーはprogressを更新できないこと" do
      diagnosis = create_monthly_challenge_diagnoses(singing_customer)
      sign_in singing_customer

      expect do
        patch singing_ai_challenge_progress_path, params: {
          diagnosis_id: diagnosis.id,
          singing_ai_challenge_progress: { tried: "1" }
        }
      end.not_to change(SingingAiChallengeProgress, :count)

      expect(response).to redirect_to(singing_diagnosis_path(diagnosis))
    end

    it "Lightユーザーはprogressを更新できないこと" do
      singing_customer.create_subscription!(status: "active", plan: "light")
      diagnosis = create_monthly_challenge_diagnoses(singing_customer)
      sign_in singing_customer

      expect do
        patch singing_ai_challenge_progress_path, params: {
          diagnosis_id: diagnosis.id,
          singing_ai_challenge_progress: { tried: "1" }
        }
      end.not_to change(SingingAiChallengeProgress, :count)

      expect(response).to redirect_to(singing_diagnosis_path(diagnosis))
    end

    it "未ログインは更新できないこと" do
      diagnosis = create_monthly_challenge_diagnoses(singing_customer)

      expect do
        patch singing_ai_challenge_progress_path, params: {
          diagnosis_id: diagnosis.id,
          singing_ai_challenge_progress: { tried: "1" }
        }
      end.not_to change(SingingAiChallengeProgress, :count)

      expect(response).to have_http_status(:found)
    end

    it "paramsに余計な値があっても更新されないこと" do
      singing_customer.create_subscription!(status: "active", plan: "core")
      diagnosis = create_monthly_challenge_diagnoses(singing_customer)
      sign_in singing_customer

      patch singing_ai_challenge_progress_path, params: {
        diagnosis_id: diagnosis.id,
        singing_ai_challenge_progress: {
          tried: "1",
          target_key: "pitch",
          metadata: { "unsafe" => true },
          completed_at: 1.year.ago
        }
      }

      progress = singing_customer.singing_ai_challenge_progresses.find_by!(target_key: "rhythm")
      expect(progress.tried).to eq true
      expect(progress.target_key).to eq "rhythm"
      expect(progress.metadata).to be_nil
      expect(progress.completed_at).to be_nil
    end

    it "current_customerのprogressのみ更新されること" do
      singing_customer.create_subscription!(status: "active", plan: "core")
      other_customer.create_subscription!(status: "active", plan: "core")
      diagnosis = create_monthly_challenge_diagnoses(singing_customer)
      other_progress = FactoryBot.create(
        :singing_ai_challenge_progress,
        customer: other_customer,
        target_key: "rhythm",
        challenge_month: Time.current.to_date.beginning_of_month,
        tried: false
      )
      sign_in singing_customer

      patch singing_ai_challenge_progress_path, params: {
        diagnosis_id: diagnosis.id,
        singing_ai_challenge_progress: { tried: "1" }
      }

      expect(singing_customer.singing_ai_challenge_progresses.find_by!(target_key: "rhythm").tried).to eq true
      expect(other_progress.reload.tried).to eq false
    end

    it "更新後、診断結果ページに戻ること" do
      singing_customer.create_subscription!(status: "active", plan: "core")
      diagnosis = create_monthly_challenge_diagnoses(singing_customer)
      sign_in singing_customer

      patch singing_ai_challenge_progress_path, params: {
        diagnosis_id: diagnosis.id,
        singing_ai_challenge_progress: { next_diagnosis_planned: "1" }
      }

      expect(response).to redirect_to(singing_diagnosis_path(diagnosis))
      follow_redirect!
      expect(response.body).to include("AIチャレンジの進捗を保存しました")
    end
  end

  describe "GET /singing/diagnoses/:id" do
    it "Coreユーザーにチェックフォームが表示されること" do
      singing_customer.create_subscription!(status: "active", plan: "core")
      diagnosis = create_monthly_challenge_diagnoses(singing_customer)
      sign_in singing_customer

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("今月の達成チェック")
      expect(response.body).to include("このチャレンジに挑戦した")
      expect(response.body).to include("進捗を保存する")
    end

    it "Coreユーザーの保存済み状態が再表示されること" do
      singing_customer.create_subscription!(status: "active", plan: "core")
      diagnosis = create_monthly_challenge_diagnoses(singing_customer)
      FactoryBot.create(
        :singing_ai_challenge_progress,
        customer: singing_customer,
        target_key: "rhythm",
        challenge_month: Time.current.to_date.beginning_of_month,
        tried: true
      )
      sign_in singing_customer

      get singing_diagnosis_path(diagnosis)

      expect(response.body).to include('name="singing_ai_challenge_progress[tried]"')
      expect(response.body).to include("checked")
    end

    it "Freeユーザーにチェックフォームが表示されないこと" do
      diagnosis = create_monthly_challenge_diagnoses(singing_customer)
      sign_in singing_customer

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("CoreプランでAIチャレンジを見る")
      expect(response.body).not_to include("今月の達成チェック")
      expect(response.body).not_to include("進捗を保存する")
    end

    it "Lightユーザーにチェックフォームが表示されないこと" do
      singing_customer.create_subscription!(status: "active", plan: "light")
      diagnosis = create_monthly_challenge_diagnoses(singing_customer)
      sign_in singing_customer

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("CoreプランでAIチャレンジを見る")
      expect(response.body).not_to include("今月の達成チェック")
      expect(response.body).not_to include("進捗を保存する")
    end
  end
end
