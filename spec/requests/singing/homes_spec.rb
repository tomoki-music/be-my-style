require 'rails_helper'

RSpec.describe "Singing::Homes", type: :request do
  let(:singing_customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let!(:singing_domain) { Domain.find_or_create_by!(name: "singing") }

  before do
    CustomerDomain.find_or_create_by!(customer: singing_customer, domain: singing_domain)
  end

  describe "GET /singing" do
    it "歌唱・演奏診断LPをプラットフォームTOPとして表示すること" do
      sign_in singing_customer

      get singing_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("歌声の今を知る")
      expect(response.body).to include("歌唱・演奏診断プラン")
      expect(response.body).to include("診断履歴を見る")
    end

    context "Recap Movie CTA（ログイン済み）" do
      before { sign_in singing_customer }

      it "Recap Movie がない場合に説明文を表示すること" do
        get singing_root_path

        expect(response.body).to include("診断を続けると、あなたの年間まとめ動画が作成されます")
      end

      it "completed な Recap Movie がある場合に視聴リンクを表示すること" do
        FactoryBot.create(:singing_generated_recap_movie, :completed, customer: singing_customer)

        get singing_root_path

        expect(response.body).to include("今年のまとめ動画を見る")
        expect(response.body).to include(singing_recap_movies_path)
      end

      it "processing な Recap Movie がある場合に生成中バッジを表示すること" do
        FactoryBot.create(:singing_generated_recap_movie, :processing, customer: singing_customer)

        get singing_root_path

        expect(response.body).to include("生成中です")
      end

      it "failed な Recap Movie がある場合に失敗バッジを表示すること" do
        FactoryBot.create(:singing_generated_recap_movie, :failed, customer: singing_customer)

        get singing_root_path

        expect(response.body).to include("生成に失敗しました")
      end
    end

    context "未ログイン時" do
      it "Recap Movie CTA を表示しないこと" do
        get singing_root_path

        expect(response.body).not_to include("Recap Movie")
      end
    end
  end
end
