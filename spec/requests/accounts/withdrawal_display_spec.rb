require "rails_helper"

# 退会後の表示: プロフィール・公開共有ページから個人情報を出さず、共有履歴は「退会済みユーザー」で残す。
RSpec.describe "退会後の表示", type: :request do
  let!(:music_domain) { Domain.find_or_create_by!(name: "music") }
  let!(:singing_domain) { Domain.find_or_create_by!(name: "singing") }
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:viewer) { create(:customer, domain_name: "music", onboarding_done: true) }
  let(:withdrawing) { create(:customer, domain_name: "music", name: "山田花子", introduction: "自己紹介です") }

  def withdraw(customer)
    result = Customers::Withdrawal::Execute.call(Customer.find(customer.id))
    raise "退会できませんでした: #{result.plan.blockers.map(&:key)}" unless result.withdrawn?
  end

  it "音楽のプロフィールは表示しない" do
    withdraw(withdrawing)
    sign_in viewer

    get public_customer_path(withdrawing)

    expect(response).to have_http_status(:redirect)
    follow_redirect!
    expect(response.body).not_to include("山田花子")
  end

  it "歌唱・演奏診断のプロフィールは、未ログインでも表示しない" do
    withdraw(withdrawing)

    get singing_user_path(withdrawing)

    expect(response).to redirect_to(singing_users_path)
  end

  it "歌唱・演奏診断の共有画像の公開ページは表示しない" do
    share_image = create(:singing_share_image, :completed, customer: withdrawing)
    token = share_image.signed_id(purpose: :public_share_image)
    get singing_public_share_image_path(token)
    expect(response).to have_http_status(:ok)

    withdraw(withdrawing)
    get singing_public_share_image_path(token)

    expect(response).to have_http_status(:not_found)
    expect(share_image.reload.image).not_to be_attached
  end

  it "活動報告は残り、投稿者は「退会済みユーザー」と表示してプロフィールへリンクしない" do
    activity = create(:activity, customer: withdrawing, title: "練習の記録")
    withdraw(withdrawing)
    sign_in viewer

    get public_activity_path(activity)

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    author = document.at_css(".activity-show-author-block")
    expect(author.text).to include("退会済みユーザー")
    expect(author.text).not_to include("山田花子")
    expect(author.at_css("a[href='#{singing_user_path(withdrawing)}']")).to be_nil
    expect(response.body).to include("練習の記録")
  end

  describe "メニューの入口" do
    it "音楽: アイコンメニューのログアウトの下に、確認画面への入口がある" do
      sign_in viewer

      get public_activities_path

      document = Nokogiri::HTML(response.body)
      pc_link = document.at_css(".customer-profile-menu .customer-profile-menu__withdrawal")
      expect(pc_link.text.strip).to eq("BeMyStyleを退会する")
      expect(pc_link["href"]).to eq(new_account_withdrawal_path(from: "music"))
      sp_link = document.at_css(".customer-menu-sp__withdrawal-item a")
      expect(sp_link["href"]).to eq(new_account_withdrawal_path(from: "music"))
      expect(sp_link.text.strip).to eq("BeMyStyleを退会する")
      expect(response.body).not_to include("NAKAMAを退会する")
      # 入口は確認画面へのリンク(GET)で、押しただけでは退会しない。
      expect(pc_link.name).to eq("a")
    end

    it "Business: 左ナビとスマートフォンのメニューに入口がある" do
      business_user = create(:customer, domain_name: "business", onboarding_done: true)
      sign_in business_user

      get business_root_path

      document = Nokogiri::HTML(response.body)
      # PC の左ナビ・スマートフォンのメニューとも、NAKAMA の名前で表示する(退会の対象はアカウント全体のまま)。
      [".ba-sidenav__withdrawal-link", ".ba-sheet__withdrawal-link"].each do |selector|
        link = document.at_css(selector)
        expect(link["href"]).to eq(new_account_withdrawal_path(from: "business"))
        expect(link.text.strip).to eq("NAKAMAを退会する")
      end
      expect(response.body).not_to include("BeMyStyleを退会する")
    end
  end
end
