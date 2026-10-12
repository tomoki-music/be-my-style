require 'rails_helper'

RSpec.describe "Business::Notifications", type: :request do
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:customer) { create(:customer, domain_name: "business", onboarding_done: true) }
  let(:actor) { create(:customer, name: "通知を送った人", domain_name: "business") }
  let(:other) { create(:customer, domain_name: "business") }
  let(:business_community) { create(:community, owner: customer, domain: business_domain) }
  let(:music_community) { create(:community, owner: customer) }
  let(:project) { Project.create!(community: business_community, customer: customer, title: "企画", description: "説明") }
  let(:post_record) { Post.create!(customer: customer, body: "ビジネス投稿") }

  def notify(action, attrs = {}, visited: customer)
    Notification.create!({ visitor: actor, visited: visited, action: action, checked: false }.merge(attrs))
  end

  let!(:business_notifications) do
    [
      notify("like", { post_id: post_record.id }),
      notify("follow"),
      notify("request", { community_id: business_community.id }),
      notify("project_message", { project_id: project.id, community_id: business_community.id })
    ]
  end
  let!(:music_notifications) do
    [
      notify("chat"),
      notify("request", { community_id: music_community.id }),
      notify("event_for_community", { community_id: music_community.id })
    ]
  end
  let!(:others_notification) { notify("like", { post_id: post_record.id }, visited: other) }

  describe "Notification.for_business" do
    it "Business の通知だけを返す(music のチャット・イベント・music コミュニティ申請は含めない)" do
      expect(customer.passive_notifications.for_business).to match_array(business_notifications)
    end
  end

  describe "ヘッダーの通知ベル" do
    before { sign_in customer }

    it "Business の未読件数だけをバッジに出し、通知一覧へリンクする" do
      get business_root_path

      bell = Nokogiri::HTML(response.body).at_css("a.business-header-bell")
      expect(bell["href"]).to eq business_notifications_path
      expect(bell.at_css(".business-header-bell__badge").text.strip).to eq "4"
      expect(bell["aria-label"]).to eq "通知（未読4件）"
    end

    it "未読がなくてもベルは表示し、バッジは出さない" do
      Notification.where(visited: customer).update_all(checked: true)

      get business_root_path

      bell = Nokogiri::HTML(response.body).at_css("a.business-header-bell")
      expect(bell).to be_present
      expect(bell.at_css(".business-header-bell__badge")).to be_nil
      expect(bell["aria-label"]).to eq "通知"
    end

    it "未ログインでは表示しない" do
      sign_out customer

      get business_root_path

      expect(Nokogiri::HTML(response.body).at_css(".business-header-bell")).to be_nil
    end
  end

  describe "GET /business/notifications" do
    before { sign_in customer }

    it "自分宛ての Business 通知だけを表示し、表示した分だけ既読にする" do
      get business_notifications_path

      html = Nokogiri::HTML(response.body)
      expect(html.css(".notification-card").size).to eq 4
      expect(business_notifications.map { |n| n.reload.checked }).to all(eq true)
      expect(music_notifications.map { |n| n.reload.checked }).to all(eq false)
      expect(others_notification.reload.checked).to eq false
    end

    it "既読後はベルのバッジが消える" do
      get business_notifications_path
      get business_root_path

      expect(Nokogiri::HTML(response.body).at_css(".business-header-bell__badge")).to be_nil
    end
  end
end
