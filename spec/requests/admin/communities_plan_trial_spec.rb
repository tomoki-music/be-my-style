require "rails_helper"

RSpec.describe "Admin の「有料機能を無料でお試し」設定", type: :request do
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business") }
  let(:community) { create(:community, owner: owner, domain: business_domain, name: "NAKAMA支部") }
  let(:other_community) { create(:community, owner: owner, domain: business_domain) }
  let(:music_community) { create(:community, owner: owner, name: "音楽サークル") }

  def update_trial(target, value)
    patch admin_community_plan_trial_path(target), params: { community: { plan_restrictions_waived: value } }
  end

  context "システム管理者" do
    before do
      # Admin 画面も ApplicationController の authenticate_customer! を通るため、既存 admin spec と同様に両方ログインする。
      sign_in create(:customer)
      sign_in create(:admin)
    end

    it "一覧に Business コミュニティの現在の状態と設定への導線が出る(Business 以外は対象外)" do
      community.update!(plan_restrictions_waived: true)
      music_community

      get admin_communities_path

      html = Nokogiri::HTML(response.body)
      expect(html.at_css("thead").text).to include("有料機能を無料でお試し")
      business_row = html.css("tbody tr").find { |tr| tr.text.include?("NAKAMA支部") }
      music_row = html.css("tbody tr").find { |tr| tr.text.include?("音楽サークル") }
      expect(business_row.at_css(".badge").text.strip).to eq "ON"
      expect(business_row.at_css(%(a[href="#{admin_community_path(community, anchor: "plan-trial")}"]))).to be_present
      expect(music_row.text).to include("対象外（Businessのみ）")
    end

    it "詳細画面にスイッチ・説明・現在の状態・解除される機能が表示される" do
      get admin_community_path(community)

      card = Nokogiri::HTML(response.body).at_css("#plan-trial")
      expect(card).to be_present
      expect(card.text).to include("有料機能を無料でお試し")
      expect(card.text).to include("ONにすると、このBusinessコミュニティ内で有料プランの対象機能を無料で利用できます。")
      expect(card.at_css(".badge").text.strip).to eq "現在：OFF"
      expect(card.css("li").map(&:text)).to eq ["プロジェクト作成（通常はCoreプラン以上）"]
      expect(card.at_css(%(form[action="#{admin_community_plan_trial_path(community)}"] input[type="checkbox"]))).to be_present
    end

    it "Business 以外のコミュニティ詳細にはスイッチを出さない" do
      get admin_community_path(music_community)

      expect(Nokogiri::HTML(response.body).at_css("#plan-trial")).to be_nil
    end

    it "ON / OFF を保存でき、保存完了が表示され、他のコミュニティには影響しない" do
      update_trial(community, "1")

      expect(response).to redirect_to(admin_community_path(community, anchor: "plan-trial"))
      expect(flash[:notice]).to eq "「有料機能を無料でお試し」をONにして保存しました。"
      expect(community.reload.plan_restrictions_waived).to eq true
      expect(other_community.reload.plan_restrictions_waived).to eq false

      follow_redirect!
      expect(response.body).to include("「有料機能を無料でお試し」をONにして保存しました。")
      expect(Nokogiri::HTML(response.body).at_css("#plan-trial .badge").text.strip).to eq "現在：ON（無料お試し中）"

      update_trial(community, "0")
      expect(flash[:notice]).to eq "「有料機能を無料でお試し」をOFFにして保存しました。"
      expect(community.reload.plan_restrictions_waived).to eq false
    end

    it "Business 以外のコミュニティは保存できない" do
      update_trial(music_community, "1")

      expect(flash[:alert]).to eq "有料機能を無料でお試しはBusinessコミュニティのみ設定できます。"
      expect(music_community.reload.plan_restrictions_waived).to eq false
    end

    it "通常の編集フォームの更新ではお試し設定は変わらない(設定の入口は1か所)" do
      patch admin_community_path(community), params: { community: { name: "改名", plan_restrictions_waived: "1" } }

      expect(community.reload.name).to eq "改名"
      expect(community.plan_restrictions_waived).to eq false
    end
  end

  context "Admin でログインしていない Customer" do
    it "コミュニティオーナーは管理画面から変更できない" do
      sign_in owner

      update_trial(community, "1")

      expect(response).to redirect_to(new_admin_session_path)
      expect(community.reload.plan_restrictions_waived).to eq false
    end

    it "管理権限を付与された CommunityOwner は管理画面から変更できない" do
      co_owner = create(:customer, domain_name: "business")
      CommunityOwner.create!(community: community, customer: co_owner)
      sign_in co_owner

      update_trial(community, "1")

      expect(response).to redirect_to(new_admin_session_path)
      expect(community.reload.plan_restrictions_waived).to eq false
    end

    it "Customer の is_owner が admin でも管理画面から変更できない" do
      sign_in create(:customer, is_owner: :admin)

      update_trial(community, "1")

      expect(response).to redirect_to(new_admin_session_path)
      expect(community.reload.plan_restrictions_waived).to eq false
    end
  end
end
