require "rails_helper"

RSpec.describe "Business::CommunityPlanTrials", type: :request do
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business") }
  let(:community) { create(:community, owner: owner, domain: business_domain) }
  let(:other_community) { create(:community, owner: owner, domain: business_domain) }
  let(:member) { create(:customer, domain_name: "business") }

  before do
    CommunityCustomer.find_or_create_by!(customer: owner, community: community)
    CommunityCustomer.find_or_create_by!(customer: member, community: community)
  end

  def toggle(target, value)
    patch business_community_plan_trial_path(target), params: { community: { plan_restrictions_waived: value } }
  end

  it "既存コミュニティの初期値は OFF" do
    expect(community.plan_restrictions_waived).to eq false
  end

  context "システム管理者(Devise の Admin でログイン中)" do
    before do
      sign_in create(:customer, domain_name: "business")
      sign_in create(:admin)
    end

    it "ON / OFF を切り替えられる" do
      toggle(community, "1")
      expect(response).to redirect_to(business_community_path(community, anchor: "plan-trial"))
      expect(flash[:notice]).to eq "「有料機能を無料でお試し」をONにして保存しました。"
      expect(community.reload.plan_restrictions_waived).to eq true

      toggle(community, "0")
      expect(flash[:notice]).to eq "「有料機能を無料でお試し」をOFFにして保存しました。"
      expect(community.reload.plan_restrictions_waived).to eq false
    end

    it "他のコミュニティの設定には波及しない" do
      toggle(community, "1")

      expect(other_community.reload.plan_restrictions_waived).to eq false
    end

    it "詳細画面に設定フォーム・現在の状態・解除される機能が表示される" do
      get business_community_path(community)

      html = Nokogiri::HTML(response.body)
      card = html.at_css("#plan-trial")
      expect(card.at_css("h3").text).to eq "有料機能を無料でお試し"
      expect(card.text).to include("ONにすると、このBusinessコミュニティ内で有料プランの対象機能を無料で利用できます。")
      expect(card.at_css(".plan-trial-card__status").text.strip).to eq "現在：OFF"
      expect(card.css(".plan-trial-card__features li").map(&:text)).to eq ["プロジェクト作成（通常はCoreプラン以上）"]
      expect(card.at_css(%(form[action="#{business_community_plan_trial_path(community)}"] input[type="checkbox"]))).to be_present

      community.update!(plan_restrictions_waived: true)
      get business_community_path(community)
      expect(Nokogiri::HTML(response.body).at_css("#plan-trial .plan-trial-card__status").text.strip).to eq "現在：ON（無料お試し中）"
    end
  end

  shared_examples "お試し設定を変更できない" do
    it "直接リクエストしても変更されない" do
      toggle(community, "1")

      expect(response).to redirect_to(business_community_path(community))
      expect(flash[:alert]).to eq "この設定はシステム管理者のみ変更できます。"
      expect(community.reload.plan_restrictions_waived).to eq false
    end

    it "ON の設定を OFF にもできない" do
      community.update!(plan_restrictions_waived: true)

      toggle(community, "0")

      expect(community.reload.plan_restrictions_waived).to eq true
    end
  end

  shared_examples "状態だけを表示し操作 UI は出さない" do
    it "設定フォームが無く、変更できない旨と現在の状態が表示される" do
      community.update!(plan_restrictions_waived: true)

      get business_community_path(community)

      card = Nokogiri::HTML(response.body).at_css("#plan-trial")
      expect(card.at_css(".plan-trial-card__status").text.strip).to eq "現在：ON（無料お試し中）"
      expect(card.text).to include("この設定はシステム管理者のみ変更できます。")
      expect(card.at_css("form, input[type='checkbox']")).to be_nil
    end
  end

  context "コミュニティオーナー" do
    before { sign_in owner }

    include_examples "お試し設定を変更できない"
    include_examples "状態だけを表示し操作 UI は出さない"
  end

  context "管理権限を付与された CommunityOwner" do
    let(:co_owner) { create(:customer, domain_name: "business") }

    before do
      CommunityOwner.create!(community: community, customer: co_owner)
      sign_in co_owner
    end

    include_examples "お試し設定を変更できない"
    include_examples "状態だけを表示し操作 UI は出さない"
  end

  context "Customer の is_owner が admin(管理画面の Admin セッションなし)" do
    before { sign_in create(:customer, is_owner: :admin) }

    include_examples "お試し設定を変更できない"
  end

  context "一般メンバー" do
    before { sign_in member }

    include_examples "お試し設定を変更できない"

    it "詳細画面に設定カードが表示されない(状態はヒーローのバッジのみ)" do
      community.update!(plan_restrictions_waived: true)

      get business_community_path(community)

      html = Nokogiri::HTML(response.body)
      expect(html.at_css("#plan-trial")).to be_nil
      expect(html.at_css(".plan-trial-badge")).to be_present
    end
  end

  context "非参加者" do
    before { sign_in create(:customer, domain_name: "business") }

    include_examples "お試し設定を変更できない"
  end

  context "コミュニティの通常の更新" do
    before { sign_in owner }

    it "パラメーターに混ぜてもお試し設定は変わらない" do
      patch business_community_path(community), params: { community: { name: "改名", plan_restrictions_waived: "1" } }

      expect(community.reload.name).to eq "改名"
      expect(community.plan_restrictions_waived).to eq false
    end
  end

  context "未ログイン" do
    it "変更できない" do
      toggle(community, "1")

      expect(response).to redirect_to(new_customer_session_path)
      expect(community.reload.plan_restrictions_waived).to eq false
    end
  end

  context "Business 以外のドメインのコミュニティ" do
    let(:music_community) { create(:community, owner: owner) }

    before do
      sign_in owner
      sign_in create(:admin)
    end

    it "Business 画面からは更新できない" do
      expect { toggle(music_community, "1") }.to raise_error(ActiveRecord::RecordNotFound)
      expect(music_community.reload.plan_restrictions_waived).to eq false
    end
  end
end
