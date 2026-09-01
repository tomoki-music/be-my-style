require 'rails_helper'

RSpec.describe "Public::CustomerFeedbacks", type: :request do
  let(:customer) { create(:customer) }
  let(:other_customer) { create(:customer) }

  describe "未ログイン" do
    it "投稿画面はログイン画面へリダイレクトされること" do
      get new_public_customer_feedback_path
      expect(response).to redirect_to(new_customer_session_path)
    end

    it "投稿できないこと" do
      expect do
        post public_customer_feedbacks_path, params: { customer_feedback: { category: "feature_request", body: "本文" } }
      end.not_to change(CustomerFeedback, :count)
    end
  end

  describe "ログイン済み" do
    before { sign_in customer }

    it "投稿画面を表示できること" do
      get new_public_customer_feedback_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ご意見・ご相談BOX")
      expect(response.body).to include("パスワードや決済情報などの機密情報は入力しないでください")
    end

    it "投稿できて一覧へリダイレクトされること（PRG）" do
      expect do
        post public_customer_feedbacks_path, params: {
          customer_feedback: { category: "bug_report", subject: "件名", body: "不具合の内容" }
        }
      end.to change(CustomerFeedback, :count).by(1)

      expect(response).to redirect_to(public_customer_feedbacks_path)
      follow_redirect!
      expect(response.body).to include("ご意見を送信しました。ご協力ありがとうございます！")
    end

    it "投稿者がcurrent_customerとして保存されること" do
      post public_customer_feedbacks_path, params: {
        customer_feedback: { category: "consultation", body: "相談内容" }
      }
      expect(CustomerFeedback.last.customer).to eq customer
    end

    it "任意のcustomer_id/status/admin_noteを送っても偽装・書き換えできないこと" do
      post public_customer_feedbacks_path, params: {
        customer_feedback: {
          category: "other",
          body: "本文",
          customer_id: other_customer.id,
          status: "completed",
          admin_note: "不正なメモ"
        }
      }

      feedback = CustomerFeedback.last
      expect(feedback.customer).to eq customer
      expect(feedback.status).to eq "unread"
      expect(feedback.admin_note).to be_nil
    end

    it "バリデーションエラーを表示すること" do
      expect do
        post public_customer_feedbacks_path, params: { customer_feedback: { category: "", body: "" } }
      end.not_to change(CustomerFeedback, :count)

      expect(response).to have_http_status(:unprocessable_entity).or have_http_status(:ok)
      expect(response.body).to include("内容を入力してください")
    end

    it "categoryパラメータを省略しても保存されずエラー表示になること" do
      expect do
        post public_customer_feedbacks_path, params: { customer_feedback: { body: "本文" } }
      end.not_to change(CustomerFeedback, :count)

      expect(response).not_to have_http_status(:error)
      expect(response.body).to include("カテゴリーを入力してください")
    end

    it "categoryに空文字を送信しても保存されずエラー表示になること" do
      expect do
        post public_customer_feedbacks_path, params: { customer_feedback: { category: "", body: "本文" } }
      end.not_to change(CustomerFeedback, :count)

      expect(response).not_to have_http_status(:error)
      expect(response.body).to include("カテゴリーを入力してください")
    end

    it "不正なカテゴリーは500にならずエラー表示になること" do
      expect do
        post public_customer_feedbacks_path, params: { customer_feedback: { category: "___invalid___", body: "本文" } }
      end.not_to change(CustomerFeedback, :count)
      expect(response).not_to have_http_status(:error)
      expect(response.body).to include("カテゴリーを入力してください")
    end

    it "正常なカテゴリーを選択すれば保存できること" do
      expect do
        post public_customer_feedbacks_path, params: { customer_feedback: { category: "feature_request", body: "本文" } }
      end.to change(CustomerFeedback, :count).by(1)
      expect(CustomerFeedback.last.category).to eq "feature_request"
    end

    it "バリデーションエラー後も選択済みカテゴリーが維持されること" do
      post public_customer_feedbacks_path, params: { customer_feedback: { category: "bug_report", body: "" } }

      expect(response.body).to include('selected="selected" value="bug_report"')
    end

    it "新規フォームではカテゴリーが自動選択されず「選択してください」が出ること" do
      get new_public_customer_feedback_path

      expect(response.body).to include('<option value="">選択してください</option>')
      expect(response.body).not_to match(/<option[^>]*selected[^>]*value="feature_request"/)
    end

    it "本文にHTML/script相当の文字列を送っても生のタグが出力されないこと" do
      xss = "<script>alert('x')</script>"
      post public_customer_feedbacks_path, params: { customer_feedback: { category: "other", subject: xss, body: xss } }

      expect(CustomerFeedback.last.body).to eq xss
      get public_customer_feedbacks_path
      expect(response.body).not_to include(xss)
    end

    describe "送信履歴" do
      let!(:own_feedback) { create(:customer_feedback, customer: customer, subject: "自分の投稿") }
      let!(:others_feedback) { create(:customer_feedback, customer: other_customer, subject: "他人の投稿", admin_note: "内部メモ") }

      it "自分の投稿だけが表示されること" do
        get public_customer_feedbacks_path
        expect(response.body).to include("自分の投稿")
        expect(response.body).not_to include("他人の投稿")
      end

      it "admin_noteは表示されないこと" do
        create(:customer_feedback, customer: customer, admin_note: "秘密のメモ")
        get public_customer_feedbacks_path
        expect(response.body).not_to include("秘密のメモ")
      end
    end

    it "PCメニュー(.customer-menu-pc)に「ご意見BOX」の導線が投稿フォームを指して表示されること" do
      get public_customer_feedbacks_path
      pc_menu = Nokogiri::HTML(response.body).at_css(".customer-menu-pc")
      link = pc_menu.css("a").find { |a| a.text.strip == "ご意見BOX" }

      expect(link).to be_present
      expect(link["href"]).to eq(new_public_customer_feedback_path)
      # ボタン内で不自然な改行(<br>)を含まない
      expect(link.inner_html).not_to include("<br")
    end

    it "スマホメニュー(.customer-menu-sp)にも同じリンク先の導線が表示されること" do
      get public_customer_feedbacks_path
      sp_menu = Nokogiri::HTML(response.body).at_css(".customer-menu-sp")
      link = sp_menu.css("a").find { |a| a.text.strip == "ご意見BOX" }

      expect(link).to be_present
      expect(link["href"]).to eq(new_public_customer_feedback_path)
    end

    it "PCメニューとスマホメニューのリンク先が一致すること" do
      get public_customer_feedbacks_path
      doc = Nokogiri::HTML(response.body)
      pc = doc.at_css(".customer-menu-pc").css("a").find { |a| a.text.strip == "ご意見BOX" }
      sp = doc.at_css(".customer-menu-sp").css("a").find { |a| a.text.strip == "ご意見BOX" }

      expect(pc["href"]).to eq(sp["href"])
      expect(pc["href"]).to eq(new_public_customer_feedback_path)
    end

    it "投稿フォームのページタイトルは正式名称「ご意見・ご相談BOX」のままであること" do
      get new_public_customer_feedback_path
      title = Nokogiri::HTML(response.body).at_css("h2.customer-feedback-title")
      expect(title.text.strip).to eq("ご意見・ご相談BOX")
    end

    it "長い件名・本文でも一覧が200で表示されること" do
      create(:customer_feedback, customer: customer, subject: "あ" * 100, body: "い" * 2000)
      get public_customer_feedbacks_path
      expect(response).to have_http_status(:ok)
    end
  end
end
