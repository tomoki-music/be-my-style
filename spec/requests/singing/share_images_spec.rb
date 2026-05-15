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
      expect(response.body).to include("成果共有ハブ")
      expect(response.body).to include("年間レポート")
      expect(response.body).to include("Daily Challenge")
      expect(response.body).to include("ランキング")
      expect(response.body).to include("singing-share-image__tab--active")
      expect(response.body).to include("target=daily-challenge")
      expect(response.body).to include("target=ranking")
      expect(response.body).to include("Instagramで共有する場合")
      expect(response.body).to include("画像を長押し保存")
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

    it "診断結果ページに年間レポートとDaily Challengeとランキングの画像シェア導線を表示すること" do
      singing_customer.create_subscription!(status: "active", plan: "core")
      sign_in singing_customer
      diagnosis = FactoryBot.create(:singing_diagnosis, :completed, customer: singing_customer, created_at: Time.current)
      FactoryBot.create(:singing_daily_challenge, challenge_date: Date.current)

      get singing_diagnosis_path(diagnosis)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("成果を画像でシェア")
      expect(response.body).to include("年間レポートをシェア")
      expect(response.body).to include("Daily Challengeをシェア")
      expect(response.body).to include("ランキングをシェア")
      expect(response.body).to include(singing_share_image_path(target: "daily-challenge"))
      expect(response.body).to include(singing_share_image_path(target: "ranking"))
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

    it "ログインユーザーがdaily_challenge targetを表示できること" do
      sign_in singing_customer
      FactoryBot.create(:singing_daily_challenge, challenge_date: Date.current)
      FactoryBot.create(:singing_diagnosis, :completed, customer: singing_customer, created_at: 1.day.ago, overall_score: 70)
      FactoryBot.create(:singing_diagnosis, :completed, customer: singing_customer, created_at: Time.current, overall_score: 74)

      get singing_share_image_path(target: "daily-challenge")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Daily Challenge")
      expect(response.body).to include("今日の一歩")
      expect(response.body).to include("+4点")
      expect(response.body).to include("data-share-capture-target='daily-challenge'")
      expect(response.body).to include("Daily Challenge を完了しました")
      expect(response.body).to include("年間レポート")
      expect(response.body).to include("Daily Challenge")
      expect(response.body).to include("ランキング")
      expect(response.body).to include("singing-share-image__tab--active")
      expect(response.body).to include("Instagramで共有する場合")
    end

    it "ログインユーザーがranking targetを表示できること" do
      sign_in singing_customer
      FactoryBot.create(:singing_diagnosis, :completed, :ranking_participant, customer: singing_customer, overall_score: 88)

      get singing_share_image_path(target: "ranking")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Singing Ranking")
      expect(response.body).to include("全国1位")
      expect(response.body).to include("総合スコア 88点")
      expect(response.body).to include("挑戦の成果がランキングに刻まれました")
      expect(response.body).to include("data-share-capture-target='ranking'")
      expect(response.body).to include("Singing Rankingに挑戦しました")
    end

    it "ranking未参加でもranking targetを自然に表示できること" do
      sign_in singing_customer

      get singing_share_image_path(target: "ranking")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ランキング参加前")
      expect(response.body).to include("次の診断でスコアを記録")
      expect(response.body).to include("次の挑戦でランキングに参加できます")
      expect(response.body).to include("data-share-capture-target='ranking'")
    end

    it "coreユーザーはmonthly-wrappedカードを表示できること" do
      singing_customer.create_subscription!(status: "active", plan: "core")
      sign_in singing_customer
      FactoryBot.create(
        :singing_diagnosis,
        :completed,
        customer: singing_customer,
        created_at: Time.zone.local(2026, 5, 10, 10, 0, 0),
        overall_score: 80
      )

      get singing_share_image_path(target: "monthly-wrapped", year: 2026, month: 5)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Monthly Wrapped")
      expect(response.body).to include("2026年5月")
      expect(response.body).to include("data-share-capture-target='monthly-wrapped'")
      expect(response.body).to include("MONTHLY WRAPPED")
    end

    it "lightユーザーはmonthly-wrappedにアクセスできずリダイレクトされること" do
      singing_customer.create_subscription!(status: "active", plan: "light")
      sign_in singing_customer

      get singing_share_image_path(target: "monthly-wrapped", year: 2026, month: 5)

      expect(response).to redirect_to(singing_diagnoses_path)
      expect(flash[:alert]).to include("Coreプラン以上")
    end

    it "freeユーザーはmonthly-wrappedにアクセスできずリダイレクトされること" do
      sign_in singing_customer

      get singing_share_image_path(target: "monthly-wrapped", year: 2026, month: 5)

      expect(response).to redirect_to(singing_diagnoses_path)
      expect(flash[:alert]).to include("Coreプラン以上")
    end

    it "対象月に診断がない場合はリダイレクトしてメッセージを表示すること" do
      singing_customer.create_subscription!(status: "active", plan: "core")
      sign_in singing_customer

      get singing_share_image_path(target: "monthly-wrapped", year: 2026, month: 5)

      expect(response).to redirect_to(singing_diagnoses_path)
      expect(flash[:alert]).to include("この月の診断記録がない")
    end

    it "premiumユーザーはyearly-wrappedカードを表示できること" do
      singing_customer.create_subscription!(status: "active", plan: "premium")
      sign_in singing_customer
      FactoryBot.create(
        :singing_diagnosis,
        :completed,
        customer: singing_customer,
        created_at: Time.zone.local(2026, 3, 10, 10, 0, 0),
        overall_score: 75
      )

      get singing_share_image_path(target: "yearly-wrapped", year: 2026)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Yearly Wrapped")
      expect(response.body).to include("2026年")
      expect(response.body).to include("data-share-capture-target='yearly-wrapped'")
      expect(response.body).to include("YEARLY WRAPPED")
    end

    it "coreユーザーはyearly-wrappedにアクセスできずリダイレクトされること" do
      singing_customer.create_subscription!(status: "active", plan: "core")
      sign_in singing_customer

      get singing_share_image_path(target: "yearly-wrapped", year: 2026)

      expect(response).to redirect_to(singing_diagnoses_path)
      expect(flash[:alert]).to include("Premiumプラン")
    end

    it "lightユーザーはyearly-wrappedにアクセスできずリダイレクトされること" do
      singing_customer.create_subscription!(status: "active", plan: "light")
      sign_in singing_customer

      get singing_share_image_path(target: "yearly-wrapped", year: 2026)

      expect(response).to redirect_to(singing_diagnoses_path)
      expect(flash[:alert]).to include("Premiumプラン")
    end

    it "freeユーザーはyearly-wrappedにアクセスできずリダイレクトされること" do
      sign_in singing_customer

      get singing_share_image_path(target: "yearly-wrapped", year: 2026)

      expect(response).to redirect_to(singing_diagnoses_path)
      expect(flash[:alert]).to include("Premiumプラン")
    end

    it "当年に診断がない場合はyearly-wrappedがリダイレクトされること" do
      singing_customer.create_subscription!(status: "active", plan: "premium")
      sign_in singing_customer

      get singing_share_image_path(target: "yearly-wrapped", year: 2026)

      expect(response).to redirect_to(singing_diagnoses_path)
      expect(flash[:alert]).to include("今年の診断記録がない")
    end

    it "legacyのcapture_target指定でもdaily_challengeを表示できること" do
      sign_in singing_customer
      FactoryBot.create(:singing_daily_challenge, challenge_date: Date.current)

      get singing_share_image_path(capture_target: "daily_challenge")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("data-share-capture-target='daily-challenge'")
    end

    it "daily_challengeのcapture token付き内部表示では対象ユーザーだけのカードを表示すること" do
      FactoryBot.create(:singing_daily_challenge, challenge_date: Date.current)
      FactoryBot.create(:singing_diagnosis, :completed, customer: singing_customer, created_at: Time.current, overall_score: 74)
      token = Singing::ShareImageCaptureToken.generate(customer: singing_customer, capture_target: "daily-challenge")

      get singing_share_image_path(target: "daily-challenge", capture_token: token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Daily Challenge")
      expect(response.body).to include("data-share-capture-target='daily-challenge'")
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
        public_url: "http://www.example.com/singing/share_images/public-token",
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
        "public_url" => "http://www.example.com/singing/share_images/public-token",
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
        public_url: "http://www.example.com/singing/share_images/premium-token",
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
        "public_url" => "http://www.example.com/singing/share_images/premium-token",
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

      post capture_singing_share_image_path, params: { capture_target: "unknown" }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("unsupported capture target")
    end

    it "daily_challenge targetで画像生成できること" do
      sign_in singing_customer
      FactoryBot.create(:singing_daily_challenge, challenge_date: Date.current)
      result = Singing::ShareImageCaptureService::Result.new(
        capture_target: "daily-challenge",
        image_url: "https://www.example.com/rails/active_storage/blobs/redirect/signed/daily-challenge-20260515-abcd1234abcd.png",
        public_url: "http://www.example.com/singing/share_images/daily-token",
        filename: "daily-challenge-20260515-abcd1234abcd.png",
        local_path: Rails.root.join("tmp/share_images/daily-challenge/sample.png")
      )
      expect(Singing::ShareImageCaptureService).to receive(:call).with(
        customer: singing_customer,
        base_url: "http://www.example.com",
        capture_target: "daily-challenge"
      ).and_return(result)

      post capture_singing_share_image_path, params: { target: "daily-challenge" }, as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to include(
        "capture_target" => "daily-challenge",
        "public_url" => "http://www.example.com/singing/share_images/daily-token",
        "local_path" => "tmp/share_images/daily-challenge/sample.png"
      )
    end

    it "ranking targetで画像生成できること" do
      sign_in singing_customer
      result = Singing::ShareImageCaptureService::Result.new(
        capture_target: "ranking",
        image_url: "https://www.example.com/rails/active_storage/blobs/redirect/signed/ranking-20260515-abcd1234abcd.png",
        public_url: "http://www.example.com/singing/share_images/ranking-token",
        filename: "ranking-20260515-abcd1234abcd.png",
        local_path: Rails.root.join("tmp/share_images/ranking/sample.png")
      )
      expect(Singing::ShareImageCaptureService).to receive(:call).with(
        customer: singing_customer,
        base_url: "http://www.example.com",
        capture_target: "ranking"
      ).and_return(result)

      post capture_singing_share_image_path, params: { target: "ranking" }, as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to include(
        "capture_target" => "ranking",
        "public_url" => "http://www.example.com/singing/share_images/ranking-token",
        "local_path" => "tmp/share_images/ranking/sample.png"
      )
    end

    it "未ログインではcapture endpointを使えないこと" do
      post capture_singing_share_image_path, params: { capture_target: "yearly-growth" }, as: :json

      expect(response).to have_http_status(:unauthorized).or have_http_status(:found)
    end
  end

  describe "GET /singing/share_images/:token" do
    it "ログインなしで期限内の公開share imageを表示し、OGP画像を出力すること" do
      share_image = FactoryBot.create(
        :singing_share_image,
        :completed,
        customer: singing_customer,
        expires_at: 1.day.from_now,
        metadata: {
          title: "公開用 歌声成長レポート",
          share_text: "公開用の説明 #BeMyStyleSinging"
        }
      )

      get singing_public_share_image_path(share_image.signed_id(purpose: :public_share_image))

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("公開用 歌声成長レポート")
      expect(response.body).to include("公開用の説明 #BeMyStyleSinging")
      expect(response.body).to include("#BeMyStyleSinging")
      expect(response.body).to include("property='og:image'")
      expect(response.body).to include("rails/active_storage/blobs")
      expect(response.body).to include("content='noindex,nofollow' name='robots'")
      expect(response.body).not_to include(singing_customer.email)
      expect(response.body).not_to include("customer_id")
    end

    it "debug_ogp=1でOGP確認用の表示を出すこと" do
      share_image = FactoryBot.create(
        :singing_share_image,
        :completed,
        customer: singing_customer,
        expires_at: 1.day.from_now,
        metadata: {
          title: "OGP確認タイトル",
          share_text: "OGP確認説明 #BeMyStyleSinging"
        }
      )

      get singing_public_share_image_path(share_image.signed_id(purpose: :public_share_image), debug_ogp: "1")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("OGP debug")
      expect(response.body).to include("og:title")
      expect(response.body).to include("og:image")
      expect(response.body).to include("noindex,nofollow")
    end

    it "daily_challengeの公開URLで自然なOGPを表示すること" do
      share_image = FactoryBot.create(
        :singing_share_image,
        :completed,
        customer: singing_customer,
        capture_target: "daily-challenge",
        expires_at: 1.day.from_now,
        metadata: {
          title: "Daily Challenge を完了しました",
          share_text: "今日もDaily Challenge完了🎤小さな一歩を積み重ねています。 #BeMyStyle"
        }
      )

      get singing_public_share_image_path(share_image.signed_id(purpose: :public_share_image), debug_ogp: "1")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Daily Challenge を完了しました")
      expect(response.body).to include("今日もDaily Challenge完了")
      expect(response.body).to include("og:title")
      expect(response.body).to include("og:description")
    end

    it "rankingの公開URLでRanking用OGPを表示すること" do
      share_image = FactoryBot.create(
        :singing_share_image,
        :completed,
        customer: singing_customer,
        capture_target: "ranking",
        expires_at: 1.day.from_now,
        metadata: {
          title: "Singing Rankingに挑戦しました",
          description: "挑戦の成果がランキングに刻まれました。",
          share_text: "Singing Rankingに挑戦しました🏆現在 全国24位🏆挑戦の成果がランキングに刻まれました。"
        }
      )

      get singing_public_share_image_path(share_image.signed_id(purpose: :public_share_image), debug_ogp: "1")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Singing Rankingに挑戦しました")
      expect(response.body).to include("挑戦の成果がランキングに刻まれました。")
      expect(response.body).to include("og:title")
      expect(response.body).to include("og:description")
    end

    it "期限切れの公開share imageは専用画面で410にすること" do
      share_image = FactoryBot.create(
        :singing_share_image,
        :completed,
        customer: singing_customer,
        expires_at: 1.minute.ago,
        metadata: { title: "Expired Share Image" }
      )

      get singing_public_share_image_path(share_image.signed_id(purpose: :public_share_image))

      expect(response).to have_http_status(:gone)
      expect(response.body).to include("このシェア画像は公開期限が終了しました")
      expect(response.body).to include("content='noindex,nofollow' name='robots'")
      expect(response.body).not_to include("Expired Share Image")
    end

    it "不正なtokenは404にすること" do
      get singing_public_share_image_path("invalid-token")

      expect(response).to have_http_status(:not_found)
    end
  end
end
