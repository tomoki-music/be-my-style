require 'rails_helper'

RSpec.describe "Singing::Battles", type: :request do
  let!(:singing_domain) { Domain.find_or_create_by!(name: "singing") }
  let(:challenger) { FactoryBot.create(:customer, domain_name: "singing") }
  let(:opponent)   { FactoryBot.create(:customer, domain_name: "singing") }

  before do
    CustomerDomain.find_or_create_by!(customer: challenger, domain: singing_domain)
    CustomerDomain.find_or_create_by!(customer: opponent,   domain: singing_domain)
  end

  let(:diagnosis) { FactoryBot.create(:singing_diagnosis, :completed, customer: challenger) }

  let(:battle) do
    SingingBattle.create!(
      challenger:           challenger,
      challenger_diagnosis: diagnosis,
      song_title:           diagnosis.song_title.presence || "無題",
      performance_type:     diagnosis.performance_type
    )
  end

  describe "GET /singing/battles/:id (show)" do
    context "チャレンジャー本人がアクセスしたとき" do
      before { sign_in challenger }

      it "200でレスポンスを返すこと" do
        get singing_battle_path(battle)
        expect(response).to have_http_status(:ok)
      end

      it "挑戦リンクのinputが join_singing_battles URL (token付き) を含むこと" do
        get singing_battle_path(battle)
        expected_url = join_singing_battles_url(token: battle.token)
        expect(response.body).to include(expected_url)
      end

      it "対象曲のタイトルを表示すること" do
        get singing_battle_path(battle)
        expect(response.body).to include(battle.song_title)
      end
    end

    context "別ユーザーがアクセスしたとき" do
      before { sign_in opponent }

      it "診断履歴へリダイレクトすること" do
        get singing_battle_path(battle)
        expect(response).to redirect_to(singing_diagnoses_path)
      end
    end
  end

  describe "GET /singing/battles/join/:token (join)" do
    context "有効なトークンで未ログインユーザーがアクセスしたとき" do
      it "200でレスポンスを返すこと" do
        get join_singing_battles_path(token: battle.token)
        expect(response).to have_http_status(:ok)
      end
    end

    context "存在しないトークンのとき" do
      it "singing_rootへリダイレクトすること" do
        get join_singing_battles_path(token: "invalid_token_xyz")
        expect(response).to redirect_to(singing_root_path)
      end
    end

    context "期限切れバトルのとき" do
      before do
        battle.update!(expires_at: 1.day.ago)
      end

      it "singing_rootへリダイレクトすること" do
        get join_singing_battles_path(token: battle.token)
        expect(response).to redirect_to(singing_root_path)
      end
    end
  end

  describe "POST /singing/battles/join/:token (accept)" do
    context "チャレンジャー本人が accept しようとしたとき" do
      before { sign_in challenger }

      it "自分には挑戦できないメッセージで join ページへリダイレクトすること" do
        post accept_singing_battles_path(token: battle.token)
        expect(response).to redirect_to(join_singing_battles_path(token: battle.token))
      end
    end

    context "ログイン済み別ユーザーが accept したとき" do
      before { sign_in opponent }

      it "新規診断ページへリダイレクトすること" do
        post accept_singing_battles_path(token: battle.token)
        expect(response).to redirect_to(new_singing_diagnosis_path(
          battle_token: battle.token,
          song_title:   battle.song_title,
          performance_type: battle.performance_type
        ))
      end
    end

    context "未ログインで accept したとき" do
      # authenticate_customer! before_action が先に実行されるため
      # Devise のデフォルトサインインページへリダイレクトされる
      it "サインインページへリダイレクトすること" do
        post accept_singing_battles_path(token: battle.token)
        expect(response).to redirect_to(new_customer_session_path)
      end
    end
  end
end
