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

      it "空状態に診断への導線を表示すること" do
        get singing_recap_movies_path

        expect(response.body).to include("診断を続けると、あなただけの年間Recap Movieが生成されます")
        expect(response.body).to include("診断を始める")
      end

      it "processing 状態のカードに生成中バッジを表示すること" do
        FactoryBot.create(:singing_generated_recap_movie, customer: owner, status: :processing)

        get singing_recap_movies_path

        expect(response.body).to include("srm-badge--processing")
        expect(response.body).to include("あなた専用のRecap Movieを生成しています")
      end

      it "completed 状態のカードに completed バッジを表示すること" do
        FactoryBot.create(:singing_generated_recap_movie, :completed, customer: owner)

        get singing_recap_movies_path

        expect(response.body).to include("srm-badge--completed")
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
        expect(response.body).to include("あなた専用のRecap Movieを生成しています")
        expect(response.body).to include("数分かかる場合があります")
      end

      it "pending の場合に生成中メッセージを表示すること" do
        movie = FactoryBot.create(:singing_generated_recap_movie, customer: owner, status: :pending)

        get singing_recap_movie_path(movie)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("あなた専用のRecap Movieを生成しています")
      end

      it "expired の場合に期限切れメッセージを表示すること" do
        movie = FactoryBot.create(:singing_generated_recap_movie, :expired, customer: owner)

        get singing_recap_movie_path(movie)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("動画の保存期限が切れました")
      end

      it "Hero タイトルに年と Recap Movie を表示すること" do
        movie = FactoryBot.create(:singing_generated_recap_movie, customer: owner, year: 2025, status: :processing)

        get singing_recap_movie_path(movie)

        expect(response.body).to include("2025 Recap Movie")
        expect(response.body).to include("Your Singing Recap")
      end

      it "completed バッジのクラスを表示すること" do
        movie = FactoryBot.create(:singing_generated_recap_movie, :completed, customer: owner)

        get singing_recap_movie_path(movie)

        expect(response.body).to include("srm-badge--completed")
      end

      it "processing バッジのクラスを表示すること" do
        movie = FactoryBot.create(:singing_generated_recap_movie, :processing, customer: owner)

        get singing_recap_movie_path(movie)

        expect(response.body).to include("srm-badge--processing")
      end

      it "診断データがある場合に診断回数を表示すること" do
        movie = FactoryBot.create(:singing_generated_recap_movie, :completed, customer: owner, year: Time.current.year)
        FactoryBot.create(:singing_diagnosis, customer: owner, status: :completed, created_at: Time.current)

        get singing_recap_movie_path(movie)

        expect(response.body).to include("診断回数")
        expect(response.body).to include("srm-meta-grid")
      end

      it "診断データがない場合にメタグリッドを表示しないこと" do
        movie = FactoryBot.create(:singing_generated_recap_movie, :processing, customer: owner)

        get singing_recap_movie_path(movie)

        expect(response.body).not_to include("srm-meta-grid")
      end

      context "Share Area" do
        it "completed かつ video_file attached の場合に share area を表示すること" do
          movie = FactoryBot.create(:singing_generated_recap_movie, :completed, customer: owner)

          get singing_recap_movie_path(movie)

          expect(response.body).to include("srm-share-area")
          expect(response.body).to include("Share Your Recap")
        end

        it "completed かつ video_file attached の場合に X share URL を含むこと" do
          movie = FactoryBot.create(:singing_generated_recap_movie, :completed, customer: owner)

          get singing_recap_movie_path(movie)

          expect(response.body).to include("twitter.com/intent/tweet")
          expect(response.body).to include("BeMyStyle")
          expect(response.body).to include("SingingRecap")
        end

        it "completed かつ video_file attached の場合にダウンロードリンクを表示すること" do
          movie = FactoryBot.create(:singing_generated_recap_movie, :completed, customer: owner)

          get singing_recap_movie_path(movie)

          expect(response.body).to include("srm-btn--download")
          expect(response.body).to include("動画を保存")
        end

        it "processing の場合に share area を表示しないこと" do
          movie = FactoryBot.create(:singing_generated_recap_movie, :processing, customer: owner)

          get singing_recap_movie_path(movie)

          expect(response.body).not_to include("srm-share-area")
        end

        it "failed の場合に share area を表示しないこと" do
          movie = FactoryBot.create(:singing_generated_recap_movie, :failed, customer: owner)

          get singing_recap_movie_path(movie)

          expect(response.body).not_to include("srm-share-area")
        end
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

  # ─── track_share ────────────────────────────────────────────────────────────

  describe "POST /singing/recap_movies/:id/track_share" do
    let!(:movie) { FactoryBot.create(:singing_generated_recap_movie, :completed, customer: owner) }

    context "未ログイン" do
      it "ログインページにリダイレクトされること" do
        post track_share_singing_recap_movie_path(movie), params: { kind: "x" }

        expect(response).to redirect_to(root_path)
      end
    end

    context "ログイン済み・自分の recap movie" do
      before { sign_in owner }

      context "kind=x" do
        it "share_count が +1 されること" do
          expect {
            post track_share_singing_recap_movie_path(movie), params: { kind: "x" }, as: :json
          }.to change { movie.reload.share_count }.by(1)
        end

        it "recap_movie_first_share バッジが付与されること" do
          expect {
            post track_share_singing_recap_movie_path(movie), params: { kind: "x" }, as: :json
          }.to change { SingingAchievementBadge.where(customer: owner, badge_key: "recap_movie_first_share").count }.by(1)
        end

        it "2回シェアしてもバッジは1件のみであること" do
          post track_share_singing_recap_movie_path(movie), params: { kind: "x" }, as: :json
          expect {
            post track_share_singing_recap_movie_path(movie), params: { kind: "x" }, as: :json
          }.not_to change { SingingAchievementBadge.where(customer: owner, badge_key: "recap_movie_first_share").count }
        end

        it "first_shared_at が初回のみセットされること" do
          post track_share_singing_recap_movie_path(movie), params: { kind: "x" }, as: :json
          first_at = movie.reload.first_shared_at
          expect(first_at).to be_present

          post track_share_singing_recap_movie_path(movie), params: { kind: "x" }, as: :json
          expect(movie.reload.first_shared_at).to be_within(1.second).of(first_at)
        end

        it "last_shared_at が更新されること" do
          post track_share_singing_recap_movie_path(movie), params: { kind: "x" }, as: :json
          expect(movie.reload.last_shared_at).to be_present
        end

        it "200 を返すこと" do
          post track_share_singing_recap_movie_path(movie), params: { kind: "x" }, as: :json
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)["ok"]).to be true
        end
      end

      context "kind=download" do
        it "download_count が +1 されること" do
          expect {
            post track_share_singing_recap_movie_path(movie), params: { kind: "download" }, as: :json
          }.to change { movie.reload.download_count }.by(1)
        end

        it "recap_movie_first_download バッジが付与されること" do
          expect {
            post track_share_singing_recap_movie_path(movie), params: { kind: "download" }, as: :json
          }.to change { SingingAchievementBadge.where(customer: owner, badge_key: "recap_movie_first_download").count }.by(1)
        end

        it "last_downloaded_at が更新されること" do
          post track_share_singing_recap_movie_path(movie), params: { kind: "download" }, as: :json
          expect(movie.reload.last_downloaded_at).to be_present
        end

        it "200 を返すこと" do
          post track_share_singing_recap_movie_path(movie), params: { kind: "download" }, as: :json
          expect(response).to have_http_status(:ok)
        end
      end

      context "kind=instagram" do
        it "instagram_hint_click_count が +1 されること" do
          expect {
            post track_share_singing_recap_movie_path(movie), params: { kind: "instagram" }, as: :json
          }.to change { movie.reload.instagram_hint_click_count }.by(1)
        end

        it "recap_movie_instagram_share バッジが付与されること" do
          expect {
            post track_share_singing_recap_movie_path(movie), params: { kind: "instagram" }, as: :json
          }.to change { SingingAchievementBadge.where(customer: owner, badge_key: "recap_movie_instagram_share").count }.by(1)
        end

        it "last_instagram_hint_clicked_at が更新されること" do
          post track_share_singing_recap_movie_path(movie), params: { kind: "instagram" }, as: :json
          expect(movie.reload.last_instagram_hint_clicked_at).to be_present
        end

        it "200 を返すこと" do
          post track_share_singing_recap_movie_path(movie), params: { kind: "instagram" }, as: :json
          expect(response).to have_http_status(:ok)
        end
      end

      context "unknown kind" do
        it "400 を返すこと" do
          post track_share_singing_recap_movie_path(movie), params: { kind: "unknown" }, as: :json
          expect(response).to have_http_status(:bad_request)
        end

        it "カウントが変更されないこと" do
          expect {
            post track_share_singing_recap_movie_path(movie), params: { kind: "unknown" }, as: :json
          }.not_to(change { movie.reload.share_count })
        end
      end
    end

    context "他人の recap movie へのアクセス" do
      before { sign_in owner }

      it "一覧ページにリダイレクトされること" do
        other_movie = FactoryBot.create(:singing_generated_recap_movie, :completed, customer: other)

        post track_share_singing_recap_movie_path(other_movie), params: { kind: "x" }, as: :json

        expect(response).to redirect_to(singing_recap_movies_path)
      end

      it "他人の share_count が変更されないこと" do
        other_movie = FactoryBot.create(:singing_generated_recap_movie, :completed, customer: other)

        expect {
          post track_share_singing_recap_movie_path(other_movie), params: { kind: "x" }, as: :json
        }.not_to(change { other_movie.reload.share_count })
      end
    end
  end

  # ─── generate_share_link ────────────────────────────────────────────────────

  describe "POST /singing/recap_movies/:id/generate_share_link" do
    context "未ログイン" do
      it "ルートにリダイレクトされること" do
        movie = FactoryBot.create(:singing_generated_recap_movie, :completed, customer: owner)

        post generate_share_link_singing_recap_movie_path(movie), as: :json

        expect(response).to redirect_to(root_path)
      end
    end

    context "ログイン済み・自分の completed movie" do
      before { sign_in owner }

      it "200 と share_url を返すこと" do
        movie = FactoryBot.create(:singing_generated_recap_movie, :completed, customer: owner)

        post generate_share_link_singing_recap_movie_path(movie), as: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["share_url"]).to include("/singing/recap_movies/share/")
      end

      it "share_token が DB に保存されること" do
        movie = FactoryBot.create(:singing_generated_recap_movie, :completed, customer: owner)

        post generate_share_link_singing_recap_movie_path(movie), as: :json

        expect(movie.reload.share_token).to be_present
      end

      it "2回呼んでも同じ URL が返ること" do
        movie = FactoryBot.create(:singing_generated_recap_movie, :completed, customer: owner)

        post generate_share_link_singing_recap_movie_path(movie), as: :json
        url1 = JSON.parse(response.body)["share_url"]

        post generate_share_link_singing_recap_movie_path(movie), as: :json
        url2 = JSON.parse(response.body)["share_url"]

        expect(url1).to eq(url2)
      end
    end

    context "expired movie" do
      before { sign_in owner }

      it "422 を返すこと" do
        movie = FactoryBot.create(:singing_generated_recap_movie, :expired, customer: owner)

        post generate_share_link_singing_recap_movie_path(movie), as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "他人の recap movie" do
      before { sign_in owner }

      it "一覧ページにリダイレクトされること" do
        other_movie = FactoryBot.create(:singing_generated_recap_movie, :completed, customer: other)

        post generate_share_link_singing_recap_movie_path(other_movie), as: :json

        expect(response).to redirect_to(singing_recap_movies_path)
      end
    end
  end

  # ─── update_share_visibility ────────────────────────────────────────────────

  describe "PATCH /singing/recap_movies/:id/update_share_visibility" do
    context "未ログイン" do
      it "ログインページにリダイレクトされること" do
        movie = FactoryBot.create(:singing_generated_recap_movie, :completed, customer: owner)

        patch update_share_visibility_singing_recap_movie_path(movie),
              params: { share_enabled: "false" }, as: :json

        expect(response).to redirect_to(root_path)
      end
    end

    context "ログイン済み・自分の completed movie" do
      before { sign_in owner }

      it "share_enabled を false にできること" do
        movie = FactoryBot.create(:singing_generated_recap_movie, :completed, customer: owner,
                                  share_enabled: true)

        patch update_share_visibility_singing_recap_movie_path(movie),
              params: { share_enabled: "false" }, as: :json

        expect(response).to have_http_status(:ok)
        expect(movie.reload.share_enabled).to be false
        expect(JSON.parse(response.body)["share_enabled"]).to be false
      end

      it "share_enabled を true に戻せること" do
        movie = FactoryBot.create(:singing_generated_recap_movie, :completed, customer: owner,
                                  share_enabled: false)

        patch update_share_visibility_singing_recap_movie_path(movie),
              params: { share_enabled: "true" }, as: :json

        expect(response).to have_http_status(:ok)
        expect(movie.reload.share_enabled).to be true
      end
    end

    context "expired movie" do
      before { sign_in owner }

      it "422 を返すこと" do
        movie = FactoryBot.create(:singing_generated_recap_movie, :expired, customer: owner)

        patch update_share_visibility_singing_recap_movie_path(movie),
              params: { share_enabled: "false" }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "failed movie" do
      before { sign_in owner }

      it "422 を返すこと" do
        movie = FactoryBot.create(:singing_generated_recap_movie, :failed, customer: owner)

        patch update_share_visibility_singing_recap_movie_path(movie),
              params: { share_enabled: "false" }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "processing movie" do
      before { sign_in owner }

      it "422 を返すこと" do
        movie = FactoryBot.create(:singing_generated_recap_movie, customer: owner, status: :processing)

        patch update_share_visibility_singing_recap_movie_path(movie),
              params: { share_enabled: "false" }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "他人の recap movie" do
      before { sign_in owner }

      it "一覧ページにリダイレクトされること" do
        other_movie = FactoryBot.create(:singing_generated_recap_movie, :completed, customer: other)

        patch update_share_visibility_singing_recap_movie_path(other_movie),
              params: { share_enabled: "false" }, as: :json

        expect(response).to redirect_to(singing_recap_movies_path)
      end
    end
  end
end
