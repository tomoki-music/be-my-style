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
      expect(response.body).to include("今日も音楽を楽しもう")
      expect(response.body).to include("今日は何をしようかな")
      expect(response.body).to include("あなたと近い仲間")
      expect(response.body).to include("歌唱・演奏診断プラン")
      expect(response.body).to include("成長記録を見る")
      expect(response.body).to include("みんなの成長")
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
      it "200 OK を返しログインページにリダイレクトしないこと" do
        get singing_root_path

        expect(response).to have_http_status(:ok)
      end

      it "ヒーロー文言を表示すること" do
        get singing_root_path

        expect(response.body).to include("自分らしく成長しよう")
      end

      it "無料で始めるCTAを表示すること" do
        get singing_root_path

        expect(response.body).to include("無料で始める")
      end

      it "Recap Movie CTA を表示しないこと" do
        get singing_root_path

        expect(response.body).not_to include("Recap Movie")
      end

      it "Community Feed は表示できるが応援CTA・Inbox・Suggested応援CTAは表示しないこと" do
        feed_member = FactoryBot.create(:customer, domain_name: "singing", name: "Feed Member")
        FactoryBot.create(:singing_diagnosis, :completed, customer: feed_member, created_at: 1.day.ago)

        get singing_root_path

        doc = Nokogiri::HTML(response.body)
        expect(response).to have_http_status(:ok)
        expect(doc.at_css(".community-feed")).to be_present
        expect(doc.css(".community-feed__cheer-button")).to be_empty
        expect(doc.css(".encouragement-inbox")).to be_empty
        expect(doc.css(".suggested-musicians__button--cheer")).to be_empty
        expect(response.body).to include("無料で始める")
        expect(response.body).to include(new_customer_registration_path)
      end
    end

    context "ログイン済み・診断あり" do
      before do
        sign_in singing_customer
      end

      it "Return Motivation Card の文脈CTAを表示すること" do
        supporter = FactoryBot.create(:customer, domain_name: "singing", name: "Supporter")
        FactoryBot.create(:singing_profile_reaction, customer: supporter, target_customer: singing_customer, reaction_type: "cheer", created_at: 3.days.ago)

        get singing_root_path

        doc = Nokogiri::HTML(response.body)
        return_cta = doc.at_css(".return-motivation-card__cta")

        expect(response).to have_http_status(:ok)
        expect(return_cta.text).to include("応援を見に行く")
        expect(return_cta["href"]).to eq("#encouragement-inbox")
        expect(doc.at_css("#encouragement-inbox")).to be_present
      end

      it "Homeの主要ブロック、応援状態、toast、プロフィール導線を表示すること" do
        supporter = FactoryBot.create(:customer, domain_name: "singing", name: "Supporter")
        reacted_member = FactoryBot.create(:customer, domain_name: "singing", name: "Reacted Member")
        fresh_member = FactoryBot.create(:customer, domain_name: "singing", name: "Fresh Member")

        FactoryBot.create(:singing_diagnosis, :completed, customer: singing_customer, overall_score: 78, pitch_score: 76, rhythm_score: 79, expression_score: 77, created_at: 3.days.ago)
        FactoryBot.create(:singing_diagnosis, :completed, customer: reacted_member, overall_score: 77, pitch_score: 76, rhythm_score: 78, expression_score: 77, created_at: 2.days.ago)
        FactoryBot.create(:singing_diagnosis, :completed, customer: fresh_member, overall_score: 76, pitch_score: 75, rhythm_score: 77, expression_score: 76, created_at: 1.day.ago)
        FactoryBot.create(:singing_profile_reaction, customer: supporter, target_customer: singing_customer, reaction_type: "cheer")
        FactoryBot.create(:singing_profile_reaction, customer: singing_customer, target_customer: reacted_member, reaction_type: "cheer")

        get singing_root_path

        doc = Nokogiri::HTML(response.body)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Today's Mission")
        expect(doc.at_css(".encouragement-inbox")).to be_present
        expect(doc.at_css(".community-feed")).to be_present
        expect(doc.at_css(".suggested-musicians")).to be_present
        expect(response.body).to include("応援する")
        expect(response.body).to include("応援済み")
        expect(response.body).to include(singing_user_path(reacted_member))
        expect(response.body).to include(singing_user_path(supporter))

        post singing_user_profile_reaction_path(fresh_member, reaction_type: "cheer"),
          headers: { "HTTP_REFERER" => singing_root_path }
        follow_redirect!

        toast_doc = Nokogiri::HTML(response.body)
        expect(toast_doc.at_css(".singing-toast").text).to include("応援が届きました")
      end
    end

    context "ログイン済み・診断なし" do
      before do
        sign_in singing_customer
      end

      it "落ちずにEmpty CTAを表示し、診断CTAは新規診断へ遷移すること" do
        get singing_root_path

        doc = Nokogiri::HTML(response.body)
        diagnosis_links = doc.css("a[href='#{new_singing_diagnosis_path}']").map(&:text).join

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("最初の一歩を踏み出そう")
        expect(diagnosis_links).to include("最初の診断をする").or include("診断してみる")
        expect(doc.css(".community-feed__item")).to be_empty
        expect(doc.css(".suggested-musician-card")).to be_empty
      end
    end

    context "HTML構造" do
      before do
        sign_in singing_customer
      end

      it "Community Feed / Suggested Musicians / Encouragement Inbox でbutton_toをlink_to内に入れないこと" do
        supporter = FactoryBot.create(:customer, domain_name: "singing", name: "Supporter")
        musician = FactoryBot.create(:customer, domain_name: "singing", name: "Musician")

        FactoryBot.create(:singing_diagnosis, :completed, customer: singing_customer, overall_score: 78, pitch_score: 76, rhythm_score: 79, expression_score: 77)
        FactoryBot.create(:singing_diagnosis, :completed, customer: musician, overall_score: 77, pitch_score: 76, rhythm_score: 78, expression_score: 77)
        FactoryBot.create(:singing_profile_reaction, customer: supporter, target_customer: singing_customer, reaction_type: "cheer")

        get singing_root_path

        doc = Nokogiri::HTML(response.body)
        %w[.community-feed .suggested-musicians .encouragement-inbox].each do |selector|
          forms_inside_links = doc.css("#{selector} form").select { |form| form.ancestors.any? { |node| node.name == "a" } }
          expect(forms_inside_links).to be_empty
        end
      end
    end
  end
end
