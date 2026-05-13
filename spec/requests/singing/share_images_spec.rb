require "rails_helper"

RSpec.describe "Singing::ShareImages", type: :request do
  let(:singing_customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let!(:singing_domain) { Domain.find_or_create_by!(name: "singing") }

  before do
    CustomerDomain.find_or_create_by!(customer: singing_customer, domain: singing_domain)
  end

  describe "GET /singing/share_image" do
    it "coreユーザーにはSNSシェア用の画像風UIを表示すること" do
      year = Time.current.year
      singing_customer.create_subscription!(status: "active", plan: "core")
      sign_in singing_customer
      FactoryBot.create(
        :singing_diagnosis,
        :completed,
        customer: singing_customer,
        song_title: "Shareable Voice",
        created_at: Time.zone.local(year, 1, 10, 10, 0, 0),
        overall_score: 60,
        pitch_score: 50,
        rhythm_score: 58,
        expression_score: 55
      )
      FactoryBot.create(
        :singing_diagnosis,
        :completed,
        customer: singing_customer,
        song_title: "Shareable Voice",
        created_at: Time.zone.local(year, 10, 10, 10, 0, 0),
        overall_score: 78,
        pitch_score: 84,
        rhythm_score: 70,
        expression_score: 68
      )
      FactoryBot.create(
        :singing_ai_challenge_progress,
        customer: singing_customer,
        target_key: "pitch",
        challenge_month: Date.new(year, 8, 1),
        tried: true
      )

      get singing_share_image_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("#{year} YEAR IN VOICE")
      expect(response.body).to include("BeMyStyle Singing")
      expect(response.body).to include("今年の診断回数")
      expect(response.body).to include("最大成長した能力")
      expect(response.body).to include("最大成長量")
      expect(response.body).to include("+34点")
      expect(response.body).to include("自己ベスト更新")
      expect(response.body).to include("最も挑戦したAIチャレンジ")
      expect(response.body).to include("最も歌った曲")
      expect(response.body).to include("Shareable Voice")
      expect(response.body).to include("#BeMyStyleSinging")
      expect(response.body).to include("Xでシェア")
      expect(response.body).to include("Instagram")
      expect(response.body).to include("スクショ")
    end

    it "freeユーザーには詳細データをHTML出力しないこと" do
      year = Time.current.year
      sign_in singing_customer
      FactoryBot.create(
        :singing_diagnosis,
        :completed,
        customer: singing_customer,
        song_title: "Free Share Song",
        created_at: Time.zone.local(year, 1, 10, 10, 0, 0),
        overall_score: 60,
        pitch_score: 50
      )
      FactoryBot.create(
        :singing_diagnosis,
        :completed,
        customer: singing_customer,
        song_title: "Free Share Song",
        created_at: Time.zone.local(year, 10, 10, 10, 0, 0),
        overall_score: 78,
        pitch_score: 84
      )

      get singing_share_image_path

      expect(response).to redirect_to(singing_diagnoses_path)
      expect(response.body).not_to include("Free Share Song")
      expect(response.body).not_to include("+34点")
      expect(flash[:alert]).to include("年間成長レポートのシェアカードはCoreプラン以上")
    end

    it "lightユーザーには詳細データをHTML出力しないこと" do
      year = Time.current.year
      singing_customer.create_subscription!(status: "active", plan: "light")
      sign_in singing_customer
      FactoryBot.create(
        :singing_diagnosis,
        :completed,
        customer: singing_customer,
        song_title: "Light Share Song",
        created_at: Time.zone.local(year, 1, 10, 10, 0, 0),
        overall_score: 60,
        pitch_score: 50
      )
      FactoryBot.create(
        :singing_diagnosis,
        :completed,
        customer: singing_customer,
        song_title: "Light Share Song",
        created_at: Time.zone.local(year, 10, 10, 10, 0, 0),
        overall_score: 78,
        pitch_score: 84
      )

      get singing_share_image_path

      expect(response).to redirect_to(singing_diagnoses_path)
      expect(response.body).not_to include("Light Share Song")
      expect(response.body).not_to include("+34点")
      expect(flash[:alert]).to include("年間成長レポートのシェアカードはCoreプラン以上")
    end

    it "診断履歴ページの共有導線もcoreユーザーにだけ表示すること" do
      singing_customer.create_subscription!(status: "active", plan: "core")
      sign_in singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, customer: singing_customer, created_at: Time.current)

      get singing_diagnoses_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("シェアカードを見る")
      expect(response.body).to include(singing_share_image_path)
    end

    it "診断履歴ページの共有導線をlightユーザーには表示しないこと" do
      singing_customer.create_subscription!(status: "active", plan: "light")
      sign_in singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, customer: singing_customer, created_at: Time.current)

      get singing_diagnoses_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("シェアカードを見る")
      expect(response.body).not_to include(singing_share_image_path)
    end
  end
end
