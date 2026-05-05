require 'rails_helper'

RSpec.describe "Singing::Rankings", type: :request do
  let(:singing_customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let(:other_customer)   { FactoryBot.create(:customer, domain_name: "singing") }
  # グローバルナビにはログイン中ユーザー名が表示されるため、
  # 「ランキングに出てはいけない」テストには未ログインの hidden_customer を使用する
  let!(:hidden_customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let!(:singing_domain)  { Domain.find_or_create_by!(name: "singing") }

  before do
    CustomerDomain.find_or_create_by!(customer: singing_customer, domain: singing_domain)
    CustomerDomain.find_or_create_by!(customer: other_customer,   domain: singing_domain)
    CustomerDomain.find_or_create_by!(customer: hidden_customer,  domain: singing_domain)
  end

  describe "GET /singing/rankings" do
    context "singingユーザーとしてアクセスした場合" do
      before { sign_in singing_customer }

      it "200 OKを返すこと" do
        get singing_rankings_path
        expect(response).to have_http_status(:ok)
      end

      it "ランキングページのタイトルを表示すること" do
        get singing_rankings_path
        expect(response.body).to include("ランキング")
      end

      it "ランキング参加者のプロフィールへのリンクを表示すること" do
        FactoryBot.create(
          :singing_diagnosis, :completed, :ranking_participant,
          customer: other_customer, overall_score: 88
        )

        get singing_rankings_path

        expect(response.body).to include(%(href="#{singing_user_path(other_customer)}"))
      end

      it "ranking_opt_in=true かつ completed の診断のみ表示すること" do
        FactoryBot.create(
          :singing_diagnosis, :completed, :ranking_participant,
          customer: other_customer, overall_score: 88
        )
        # hidden_customer は未ログインのためナビには出現しない → ランキング除外を正確に検証できる
        FactoryBot.create(
          :singing_diagnosis, :completed,
          customer: hidden_customer, overall_score: 90
        )

        get singing_rankings_path

        expect(response.body).to include(other_customer.name)
        expect(response.body).not_to include(hidden_customer.name)
      end

      it "ranking_opt_in=false の診断はランキングに表示しないこと" do
        FactoryBot.create(
          :singing_diagnosis, :completed,
          customer: hidden_customer, overall_score: 95, ranking_opt_in: false
        )

        get singing_rankings_path

        expect(response.body).not_to include(hidden_customer.name)
      end

      it "failed ステータスの診断はランキングに表示しないこと" do
        FactoryBot.create(
          :singing_diagnosis,
          customer: hidden_customer,
          status: :failed,
          overall_score: 80,
          ranking_opt_in: true
        )

        get singing_rankings_path

        expect(response.body).not_to include(hidden_customer.name)
      end

      it "queued/processing ステータスの診断はランキングに表示しないこと" do
        FactoryBot.create(
          :singing_diagnosis,
          customer: hidden_customer,
          status: :queued,
          ranking_opt_in: true
        )

        get singing_rankings_path

        expect(response.body).not_to include(hidden_customer.name)
      end

      it "overall_score が nil の診断はランキングに表示しないこと" do
        FactoryBot.create(
          :singing_diagnosis,
          customer: hidden_customer,
          status: :completed,
          overall_score: nil,
          ranking_opt_in: true
        )

        get singing_rankings_path

        expect(response.body).not_to include(hidden_customer.name)
      end

      it "同一ユーザーの複数診断のうち、最高スコアのみ表示すること（重複なし）" do
        # other_customer は未ログインのためナビには出現しない → 正確に出現回数を検証できる
        FactoryBot.create(
          :singing_diagnosis, :completed, :ranking_participant,
          customer: other_customer, overall_score: 70
        )
        FactoryBot.create(
          :singing_diagnosis, :completed, :ranking_participant,
          customer: other_customer, overall_score: 90
        )

        get singing_rankings_path

        # 同一ユーザーがランキングに1回だけ登場すること
        occurrences = response.body.scan(other_customer.name).count
        expect(occurrences).to eq(1)
      end

      it "同一ユーザーの低スコア診断ではなく最高スコア（90点）が表示されること" do
        FactoryBot.create(
          :singing_diagnosis, :completed, :ranking_participant,
          customer: other_customer, overall_score: 70
        )
        FactoryBot.create(
          :singing_diagnosis, :completed, :ranking_participant,
          customer: other_customer, overall_score: 90
        )

        get singing_rankings_path

        # ランキングに90点の診断が採用されていること（スコア表示あり）
        expect(response.body).to include(">90<")
      end

      it "同スコアの別ユーザーは双方表示されること" do
        customer_a = FactoryBot.create(:customer, domain_name: "singing")
        customer_b = FactoryBot.create(:customer, domain_name: "singing")
        CustomerDomain.find_or_create_by!(customer: customer_a, domain: singing_domain)
        CustomerDomain.find_or_create_by!(customer: customer_b, domain: singing_domain)

        FactoryBot.create(
          :singing_diagnosis, :completed, :ranking_participant,
          customer: customer_a, overall_score: 80
        )
        FactoryBot.create(
          :singing_diagnosis, :completed, :ranking_participant,
          customer: customer_b, overall_score: 80
        )

        get singing_rankings_path

        expect(response.body).to include(customer_a.name)
        expect(response.body).to include(customer_b.name)
      end

      it "スコア降順でランキングが表示されること" do
        customer_a = FactoryBot.create(:customer, domain_name: "singing")
        customer_b = FactoryBot.create(:customer, domain_name: "singing")
        CustomerDomain.find_or_create_by!(customer: customer_a, domain: singing_domain)
        CustomerDomain.find_or_create_by!(customer: customer_b, domain: singing_domain)

        FactoryBot.create(
          :singing_diagnosis, :completed, :ranking_participant,
          customer: customer_a, overall_score: 60
        )
        FactoryBot.create(
          :singing_diagnosis, :completed, :ranking_participant,
          customer: customer_b, overall_score: 85
        )

        get singing_rankings_path

        # ポディウムは 2位(左)→1位(中央)→3位(右) の順でDOMに出力される
        # customer_b(85点=1位)は中央カード、customer_a(60点=2位)は左カードに表示
        pos_a = response.body.index(customer_a.name)
        pos_b = response.body.index(customer_b.name)
        expect(pos_a).to be < pos_b
        expect(response.body).to include("1st")
        expect(response.body).to include("2nd")
      end

      it "ランキング参加者がいない場合に空状態メッセージを表示すること" do
        get singing_rankings_path
        expect(response.body).to include("まだランキング参加者はいません")
      end

      it "プライバシー注意書きを表示すること" do
        get singing_rankings_path
        expect(response.body).to include("ランキング参加は任意です")
      end

      context "タブ構造" do
        it "総合ランキングタブを表示すること" do
          get singing_rankings_path
          expect(response.body).to include("総合ランキング")
        end

        it "成長ランキング（Coming Soon）タブを表示すること" do
          get singing_rankings_path
          expect(response.body).to include("成長ランキング")
          expect(response.body).to include("COMING SOON")
        end

        it "シーズンランキング（Coming Soon）タブを表示すること" do
          get singing_rankings_path
          expect(response.body).to include("シーズンランキング")
        end
      end

      context "自分の順位表示" do
        it "ランキング参加中のユーザーには現在順位を表示すること" do
          FactoryBot.create(
            :singing_diagnosis, :completed, :ranking_participant,
            customer: singing_customer, overall_score: 80
          )

          get singing_rankings_path

          expect(response.body).to include("あなたの現在順位")
          expect(response.body).to include("ランキング参加中")
        end

        it "ランキング未参加のユーザーには診断CTAを表示すること" do
          get singing_rankings_path

          expect(response.body).to include("診断を始める")
          expect(response.body).to include("ランキング参加をONにすると掲載されます")
        end
      end
    end

    context "未ログインの場合" do
      it "リダイレクトされること" do
        get singing_rankings_path
        expect(response).not_to have_http_status(:ok)
      end
    end
  end

  describe "POST /singing/diagnoses" do
    before { sign_in singing_customer }

    it "ranking_opt_in=true で診断を作成できること" do
      audio = fixture_file_upload(Rails.root.join("spec/fixtures/11megabytes_sample.png"), "audio/mpeg")

      post singing_diagnoses_path, params: {
        singing_diagnosis: {
          audio_file: audio,
          performance_type: "vocal",
          ranking_opt_in: "1"
        }
      }

      diagnosis = SingingDiagnosis.last
      expect(diagnosis.ranking_opt_in).to be true
    end

    it "ranking_opt_in 未選択時は false で保存されること" do
      audio = fixture_file_upload(Rails.root.join("spec/fixtures/11megabytes_sample.png"), "audio/mpeg")

      post singing_diagnoses_path, params: {
        singing_diagnosis: {
          audio_file: audio,
          performance_type: "vocal"
        }
      }

      diagnosis = SingingDiagnosis.last
      expect(diagnosis.ranking_opt_in).to be false
    end
  end
end
