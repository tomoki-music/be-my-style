require 'rails_helper'

RSpec.describe "Singing::PublicRecapMovies", type: :request do
  let!(:singing_domain) { Domain.find_or_create_by!(name: "singing") }
  let(:owner) { FactoryBot.create(:customer, domain_name: "singing") }

  before do
    CustomerDomain.find_or_create_by!(customer: owner, domain: singing_domain)
  end

  describe "GET /singing/recap_movies/share/:share_token" do
    context "有効な share_token・completed・video_file あり" do
      it "200 を返すこと" do
        movie = FactoryBot.create(:singing_generated_recap_movie, :completed, customer: owner,
                                  share_token: "valid_token_abc123")

        get singing_public_recap_movie_share_path(share_token: "valid_token_abc123")

        expect(response).to have_http_status(:ok)
      end

      it "ユーザー名と年を表示すること" do
        movie = FactoryBot.create(:singing_generated_recap_movie, :completed, customer: owner,
                                  year: 2025, share_token: "tok_show_name")

        get singing_public_recap_movie_share_path(share_token: "tok_show_name")

        expect(response.body).to include(owner.name)
        expect(response.body).to include("2025")
      end

      it "video タグを含むこと" do
        FactoryBot.create(:singing_generated_recap_movie, :completed, customer: owner,
                          share_token: "tok_video")

        get singing_public_recap_movie_share_path(share_token: "tok_video")

        expect(response.body).to include("<video")
      end

      it "BeMyStyle 登録 CTA を表示すること" do
        FactoryBot.create(:singing_generated_recap_movie, :completed, customer: owner,
                          share_token: "tok_cta")

        get singing_public_recap_movie_share_path(share_token: "tok_cta")

        expect(response.body).to include("無料ではじめる")
      end

      it "X シェアリンクを含むこと" do
        FactoryBot.create(:singing_generated_recap_movie, :completed, customer: owner,
                          share_token: "tok_twitter")

        get singing_public_recap_movie_share_path(share_token: "tok_twitter")

        expect(response.body).to include("twitter.com/intent/tweet")
      end

      it "LINE シェアリンクを含むこと" do
        FactoryBot.create(:singing_generated_recap_movie, :completed, customer: owner,
                          share_token: "tok_line")

        get singing_public_recap_movie_share_path(share_token: "tok_line")

        expect(response.body).to include("line.me")
      end

      it "ログイン不要でアクセスできること" do
        FactoryBot.create(:singing_generated_recap_movie, :completed, customer: owner,
                          share_token: "tok_nologin")

        get singing_public_recap_movie_share_path(share_token: "tok_nologin")

        expect(response).to have_http_status(:ok)
      end
    end

    context "存在しない share_token" do
      it "404 を返すこと" do
        get singing_public_recap_movie_share_path(share_token: "nonexistent_token")

        expect(response).to have_http_status(:not_found)
      end
    end

    context "expired な movie" do
      it "404 を返すこと" do
        movie = FactoryBot.create(:singing_generated_recap_movie, :expired, customer: owner,
                                  share_token: "tok_expired")

        get singing_public_recap_movie_share_path(share_token: "tok_expired")

        expect(response).to have_http_status(:not_found)
      end
    end

    context "failed な movie" do
      it "404 を返すこと" do
        movie = FactoryBot.create(:singing_generated_recap_movie, :failed, customer: owner,
                                  share_token: "tok_failed")

        get singing_public_recap_movie_share_path(share_token: "tok_failed")

        expect(response).to have_http_status(:not_found)
      end
    end

    context "processing な movie" do
      it "404 を返すこと" do
        movie = FactoryBot.create(:singing_generated_recap_movie, :processing, customer: owner,
                                  share_token: "tok_processing")

        get singing_public_recap_movie_share_path(share_token: "tok_processing")

        expect(response).to have_http_status(:not_found)
      end
    end

    context "expires_at が過去の completed movie" do
      it "404 を返すこと" do
        movie = FactoryBot.create(:singing_generated_recap_movie, :completed, customer: owner,
                                  expires_at: 1.second.ago, share_token: "tok_expired_at")

        get singing_public_recap_movie_share_path(share_token: "tok_expired_at")

        expect(response).to have_http_status(:not_found)
      end
    end

    context "share_token は一致するが video_file が未添付" do
      it "404 を返すこと" do
        movie = FactoryBot.create(:singing_generated_recap_movie, customer: owner,
                                  status: :completed, generated_at: Time.current,
                                  expires_at: 1.day.from_now, share_token: "tok_no_video")

        get singing_public_recap_movie_share_path(share_token: "tok_no_video")

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
