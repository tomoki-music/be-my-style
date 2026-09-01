require 'rails_helper'

RSpec.describe "ご意見・ご相談BOX（ユーザー側）", type: :system do
  let(:customer) { create(:customer, :customer_with_parts) }

  def sign_in_via_form(target_customer)
    visit new_customer_session_path
    fill_in "customer_email", with: target_customer.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_content("ログインしました", wait: 10)
  end

  before { sign_in_via_form(customer) }

  it "PCメニュー・スマホメニュー両方に短縮名「ご意見BOX」の導線が表示され、同じ遷移先を指すこと" do
    visit public_homes_top_path

    sp_links = page.all(".customer-menu-sp a", text: "ご意見BOX", exact_text: true).to_a
    pc_links = page.all(".customer-menu-pc a", text: "ご意見BOX", exact_text: true).to_a

    expect(sp_links).not_to be_empty
    expect(pc_links).not_to be_empty
    expect((sp_links + pc_links).map { |a| a[:href] }.uniq).to eq([new_public_customer_feedback_path])
  end

  it "ログイン後TOPに補助カードが表示されること" do
    visit public_homes_top_path
    expect(page).to have_content("BeMyStyleへのご意見・ご相談はこちら")
    expect(page).to have_link("ご意見・ご相談BOXを開く", href: new_public_customer_feedback_path)
  end

  it "投稿フォームで案内文が表示され、カテゴリーが自動選択されていないこと" do
    visit new_public_customer_feedback_path

    expect(page).to have_content("機能のご要望、不具合のご報告、お困りごとなどをお気軽にお送りください")
    expect(page).to have_content("パスワードや決済情報などの機密情報は入力しないでください")

    # 新規表示時は有効な category が選択されておらず、prompt「選択してください」が出ている
    expect(page.find("select#customer_feedback_category").value).to be_blank
    expect(page).to have_css("select#customer_feedback_category option[value='']", text: "選択してください")
    expect(page).not_to have_css("select#customer_feedback_category option[selected][value='feature_request']")
  end

  it "カテゴリー未選択で送信するとエラーになり保存されないこと" do
    visit new_public_customer_feedback_path
    fill_in "customer_feedback[body]", with: "本文だけ入力"

    expect do
      click_button "送信する"
    end.not_to change(CustomerFeedback, :count)

    expect(page).to have_content("カテゴリーを入力してください")
  end

  it "投稿に成功すると送信履歴へ遷移し、成功メッセージと投稿が表示されること" do
    visit new_public_customer_feedback_path
    select "アプリの不具合修正要望", from: "customer_feedback[category]"
    fill_in "customer_feedback[subject]", with: "検索結果が出ないことがある"
    fill_in "customer_feedback[body]", with: "イベント検索でまれに結果が0件になります。"

    click_button "送信する"

    expect(page).to have_content("ご意見を送信しました。ご協力ありがとうございます！")
    expect(page).to have_content("送信履歴")
    expect(page).to have_content("検索結果が出ないことがある")
    expect(page).to have_content("アプリの不具合修正要望")
    expect(page).to have_content("未確認")
  end

  it "長い本文・改行・絵文字を含む投稿でも履歴画面が崩れず表示されること" do
    body = "🎤 不具合の報告です。\n\n" + ("あ" * 1500)
    create(:customer_feedback, customer: customer, category: :bug_report, subject: "😀" * 30, body: body)

    visit public_customer_feedbacks_path

    expect(page).to have_content("😀😀")
    # 一覧テーブルは横スクロール用ラッパー(.table-responsive)で包む
    expect(page).to have_css(".table-responsive .customer-feedback-table")
  end

  it "他ユーザーの投稿は送信履歴に表示されないこと" do
    other = create(:customer, :customer_with_parts)
    create(:customer_feedback, customer: other, subject: "他人の投稿タイトル")
    create(:customer_feedback, customer: customer, subject: "自分の投稿タイトル")

    visit public_customer_feedbacks_path

    expect(page).to have_content("自分の投稿タイトル")
    expect(page).not_to have_content("他人の投稿タイトル")
  end
end
