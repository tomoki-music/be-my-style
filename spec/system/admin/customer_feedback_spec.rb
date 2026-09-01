require 'rails_helper'

RSpec.describe "ご意見・ご相談BOX（管理側）", type: :system do
  let(:admin) { create(:admin) }
  let(:customer) { create(:customer) }

  def sign_in_admin_via_form(target_admin)
    visit new_admin_session_path
    fill_in "admin_email", with: target_admin.email
    fill_in "admin_password", with: "admin-password"
    click_button "管理者としてログイン"
  end

  before { sign_in_admin_via_form(admin) }

  it "管理メニュー(PC/スマホ)に未確認件数バッジが表示されること" do
    create_list(:customer_feedback, 2, customer: customer, status: :unread)
    create(:customer_feedback, customer: customer, status: :completed)

    visit admin_customer_feedbacks_path

    within(".admin-menu-pc") { expect(page).to have_link("ご意見BOX") }
    within(".admin-menu-sp") { expect(page).to have_link("ご意見BOX") }
    # 未確認は2件
    expect(page.all(".admin-menu-pc a", text: "ご意見BOX").first).to have_content("2")
  end

  it "一覧・絞り込み・詳細・更新が動作すること" do
    feature = create(:customer_feedback, customer: customer, category: :feature_request, subject: "機能要望A", body: "本文A")
    bug = create(:customer_feedback, customer: customer, category: :bug_report, subject: "不具合B", body: "本文B")

    visit admin_customer_feedbacks_path
    expect(page).to have_content("機能要望A")
    expect(page).to have_content("不具合B")
    expect(page).to have_content("未確認")

    select "アプリの不具合修正要望", from: "category"
    click_button "絞り込む"
    expect(page).to have_content("不具合B")
    expect(page).not_to have_content("機能要望A")

    click_link "詳細", match: :first
    expect(page).to have_content("本文B")

    select "確認中", from: "customer_feedback[status]"
    fill_in "customer_feedback[admin_note]", with: "担当者アサイン済み"
    click_button "更新する"

    expect(page).to have_content("対応状況を更新しました。")
    expect(bug.reload.status).to eq "reviewing"
    expect(bug.admin_note).to eq "担当者アサイン済み"
  end

  it "退会済みユーザーの投稿でも一覧・詳細がエラーにならないこと" do
    feedback = create(:customer_feedback, customer: customer, subject: "退会前の投稿")
    customer.update!(is_deleted: true)

    visit admin_customer_feedbacks_path
    expect(page).to have_content("退会済みユーザー")

    click_link "詳細", match: :first
    expect(page).to have_content("退会前の投稿")
    expect(page).to have_content("退会済み")
  end

  it "長文の管理者向け本文が折り返し表示用のコンテナに入ること" do
    create(:customer_feedback, customer: customer, body: ("z" * 800))
    visit admin_customer_feedbacks_path
    click_link "詳細", match: :first
    expect(page).to have_css(".customer-feedback-body")
  end
end
