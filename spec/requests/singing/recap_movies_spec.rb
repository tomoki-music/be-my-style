require 'rails_helper'

RSpec.describe "Singing::RecapMovies", type: :request do
  let!(:singing_domain) { Domain.find_or_create_by!(name: "singing") }

  let(:owner)  { FactoryBot.create(:customer, domain_name: "singing") }
  let(:other)  { FactoryBot.create(:customer, domain_name: "singing") }

  before do
    CustomerDomain.find_or_create_by!(customer: owner, domain: singing_domain)
    CustomerDomain.find_or_create_by!(customer: other, domain: singing_domain)
  end

  # ─── index ──────────────────────────────────────────────────────────────────

  describe "GET /singing/recap_movies" do
    context "未ログイン" do
      it "ログインページにリダイレクトされること" do
        get singing_recap_movies_path

        expect(response).to redirect_to(root_path)
      end
    end

    context "ログイン済み" do
      before { sign_in owner }

      it "200を返すこと" do
        get singing_recap_movies_path

        expect(response).to have_http_status(:ok)
      end

      it "自分の Recap Movie の年を表示すること" do
        FactoryBot.create(:singing_generated_recap_movie, customer: owner, year: 2024, status: :completed)

        get singing_recap_movies_path

        expect(response.body).to include("2024")
      end

      it "他人の Recap Movie を表示しないこと" do
        FactoryBot.create(:singing_generated_recap_movie, customer: other, year: 2023, status: :completed)

        get singing_recap_movies_path

        expect(response.body).not_to include("2023")
      end

      it "Recap Movie がない場合に空状態メッセージを表示すること" do
        get singing_recap_movies_path

        expect(response.body).to include("まだ Recap Movie はありません")
      end
    end
  end

  # ─── show ───────────────────────────────────────────────────────────────────

  describe "GET /singing/recap_movies/:id" do
    context "未ログイン" do
      it "ログインページにリダイレクトされること" do
        movie = FactoryBot.create(:singing_generated_recap_movie, customer: owner)

        get singing_recap_movie_path(movie)

        expect(response).to redirect_to(root_path)
      end
    end

    context "ログイン済み・自分の Recap Movie" do
      before { sign_in owner }

      it "completed かつ video_file attached の場合に video タグを表示すること" do
        movie = FactoryBot.create(:singing_generated_recap_movie, :completed, customer: owner)

        get singing_recap_movie_path(movie)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("<video")
      end

      it "failed の場合に失敗メッセージを表示すること" do
        movie = FactoryBot.create(:singing_generated_recap_movie, :failed, customer: owner)

        get singing_recap_movie_path(movie)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("動画の生成に失敗しました")
      end

      it "processing の場合に生成中メッセージを表示すること" do
        movie = FactoryBot.create(:singing_generated_recap_movie, :processing, customer: owner)

        get singing_recap_movie_path(movie)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("動画を生成しています")
      end

      it "pending の場合に生成中メッセージを表示すること" do
        movie = FactoryBot.create(:singing_generated_recap_movie, customer: owner, status: :pending)

        get singing_recap_movie_path(movie)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("動画を生成しています")
      end

      it "expired の場合に期限切れメッセージを表示すること" do
        movie = FactoryBot.create(:singing_generated_recap_movie, :expired, customer: owner)

        get singing_recap_movie_path(movie)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("動画の保存期限が切れました")
      end
    end

    context "他人の Recap Movie へのアクセス" do
      before { sign_in owner }

      it "一覧ページにリダイレクトされること" do
        other_movie = FactoryBot.create(:singing_generated_recap_movie, customer: other)

        get singing_recap_movie_path(other_movie)

        expect(response).to redirect_to(singing_recap_movies_path)
      end
    end
  end
end
