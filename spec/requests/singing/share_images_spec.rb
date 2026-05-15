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
      long_song_title = "Shareable Voice with a Very Long Mobile Screenshot Title 2026"
      singing_customer.create_subscription!(status: "active", plan: "core")
      sign_in singing_customer
      FactoryBot.create(
        :singing_diagnosis,
        :completed,
        customer: singing_customer,
        song_title: long_song_title,
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
        song_title: long_song_title,
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
      expect(response.body).to include(long_song_title)
      expect(response.body).to include("#BeMyStyleSinging")
      expect(response.body).to include("Xでシェア")
      expect(response.body).to include("Instagram")
      expect(response.body).to include("スクショ")
      expect(response.body).to include("診断を続ける")
      expect(response.body).to include("履歴へ戻る")
      expect(response.body).to include("data-share-capture-target='yearly-growth'")
      expect(response.body).to include("property='og:title'")
      expect(response.body).to include("#{year}年 歌声成長レポート")
      expect(response.body).to include("name='twitter:card'")
      expect(response.body).to include("summary_large_image")
      expect(response.body).to include(new_singing_diagnosis_path)
      expect(response.body).to include(singing_diagnoses_path)
    end

    it "データが少ないcoreユーザーにも集計待ちのシェアカードを表示すること" do
      year = Time.current.year
      singing_customer.create_subscription!(status: "active", plan: "core")
      sign_in singing_customer
      FactoryBot.create(
        :singing_diagnosis,
        :completed,
        customer: singing_customer,
        song_title: "First Song",
        created_at: Time.zone.local(year, 5, 10, 10, 0, 0),
        overall_score: 60,
        pitch_score: 50
      )

      get singing_share_image_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("集計待ち")
      expect(response.body).to include("2回以上の診断で集計")
      expect(response.body).to include("未挑戦")
      expect(response.body).to include("First Song")
    end

    it "premiumユーザーにもSNSシェア用の画像風UIを表示すること" do
      year = Time.current.year
      singing_customer.create_subscription!(status: "active", plan: "premium")
      sign_in singing_customer
      FactoryBot.create(
        :singing_diagnosis,
        :completed,
        customer: singing_customer,
        song_title: "Premium Share Song",
        created_at: Time.zone.local(year, 1, 10, 10, 0, 0),
        overall_score: 60,
        pitch_score: 50
      )

      get singing_share_image_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("#{year} YEAR IN VOICE")
      expect(response.body).to include("Premium Share Song")
      expect(response.body).to include("Xでシェア")
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

    it "capture token付きの内部表示では対象ユーザーのシェアカードを表示すること" do
      year = Time.current.year
      singing_customer.create_subscription!(status: "active", plan: "core")
      FactoryBot.create(
        :singing_diagnosis,
        :completed,
        customer: singing_customer,
        song_title: "Token Capture Song",
        created_at: Time.zone.local(year, 1, 10, 10, 0, 0)
      )
      token = Singing::ShareImageCaptureToken.generate(customer: singing_customer, capture_target: "yearly-growth")

      get singing_share_image_path(capture_target: "yearly-growth", capture_token: token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Token Capture Song")
      expect(response.body).to include("data-share-capture-target='yearly-growth'")
    end

    it "不正なcapture tokenではシェアカードを表示しないこと" do
      singing_customer.create_subscription!(status: "active", plan: "core")
      FactoryBot.create(:singing_diagnosis, :completed, customer: singing_customer, song_title: "Hidden Song")

      get singing_share_image_path(capture_target: "yearly-growth", capture_token: "invalid")

      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include("Hidden Song")
    end
  end

  describe "POST /singing/share_image/capture" do
    it "coreユーザーは一時png生成結果をJSONで受け取れること" do
      singing_customer.create_subscription!(status: "active", plan: "core")
      sign_in singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, customer: singing_customer, song_title: "Capture Song")
      result = Singing::ShareImageCaptureService::Result.new(
        capture_target: "yearly-growth",
        image_url: "https://www.example.com/rails/active_storage/blobs/redirect/signed/yearly-growth-20260515-abcd1234abcd.png",
        filename: "yearly-growth-20260515-abcd1234abcd.png",
        local_path: Rails.root.join("tmp/share_images/yearly-growth/sample.png")
      )
      expect(Singing::ShareImageCaptureService).to receive(:call).with(
        customer: singing_customer,
        base_url: "http://www.example.com",
        capture_target: "yearly-growth"
      ).and_return(result)

      post capture_singing_share_image_path, params: { capture_target: "yearly-growth" }, as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to include(
        "capture_target" => "yearly-growth",
        "image_url" => "https://www.example.com/rails/active_storage/blobs/redirect/signed/yearly-growth-20260515-abcd1234abcd.png",
        "filename" => "yearly-growth-20260515-abcd1234abcd.png",
        "local_path" => "tmp/share_images/yearly-growth/sample.png"
      )
    end

    it "premiumユーザーも保存済み画像URLをJSONで受け取れること" do
      singing_customer.create_subscription!(status: "active", plan: "premium")
      sign_in singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, customer: singing_customer, song_title: "Premium Capture Song")
      result = Singing::ShareImageCaptureService::Result.new(
        capture_target: "yearly-growth",
        image_url: "https://www.example.com/rails/active_storage/blobs/redirect/signed/yearly-growth-20260515-1234abcd1234.png",
        filename: "yearly-growth-20260515-1234abcd1234.png",
        local_path: Rails.root.join("tmp/share_images/yearly-growth/premium.png")
      )
      expect(Singing::ShareImageCaptureService).to receive(:call).with(
        customer: singing_customer,
        base_url: "http://www.example.com",
        capture_target: "yearly-growth"
      ).and_return(result)

      post capture_singing_share_image_path, params: { capture_target: "yearly-growth" }, as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to include(
        "capture_target" => "yearly-growth",
        "image_url" => "https://www.example.com/rails/active_storage/blobs/redirect/signed/yearly-growth-20260515-1234abcd1234.png",
        "filename" => "yearly-growth-20260515-1234abcd1234.png",
        "local_path" => "tmp/share_images/yearly-growth/premium.png"
      )
    end

    it "freeユーザーは画像生成できず、詳細データも返さないこと" do
      sign_in singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, customer: singing_customer, song_title: "Free Capture Song")

      post capture_singing_share_image_path, params: { capture_target: "yearly-growth" }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(response.body).not_to include("Free Capture Song")
      expect(response.body).to include("Coreプラン以上")
    end

    it "lightユーザーは画像生成できず、詳細データも返さないこと" do
      singing_customer.create_subscription!(status: "active", plan: "light")
      sign_in singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, customer: singing_customer, song_title: "Light Capture Song")

      post capture_singing_share_image_path, params: { capture_target: "yearly-growth" }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(response.body).not_to include("Light Capture Song")
      expect(response.body).to include("Coreプラン以上")
    end

    it "未対応capture targetは画像生成しないこと" do
      singing_customer.create_subscription!(status: "active", plan: "core")
      sign_in singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, customer: singing_customer)
      expect(Singing::ShareImageCaptureService).not_to receive(:call)

      post capture_singing_share_image_path, params: { capture_target: "ranking" }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("unsupported capture target")
    end

    it "未ログインではcapture endpointを使えないこと" do
      post capture_singing_share_image_path, params: { capture_target: "yearly-growth" }, as: :json

      expect(response).to have_http_status(:unauthorized).or have_http_status(:found)
    end
  end
end
