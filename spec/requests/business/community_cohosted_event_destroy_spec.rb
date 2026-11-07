require "rails_helper"

RSpec.describe "Business コミュニティの削除と共催イベント", type: :request do
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { FactoryBot.create(:customer, domain_name: "business") }
  let(:community) { FactoryBot.create(:community, owner_id: owner.id, domain: business_domain) }
  let(:cohost) { FactoryBot.create(:community, domain: business_domain) }
  let!(:event) { FactoryBot.create(:event, :event_with_songs, community: community, event_name: "合同企画") }

  before do
    event.update!(selected_cohost_community_ids: [cohost.id])
    sign_in owner
  end

  it "共催イベントを主催していると削除できず、消えない案内ページへ移動する" do
    expect { delete business_community_path(community) }.not_to change(Community, :count)

    expect(response).to redirect_to(destroy_blocked_business_community_path(community))
    follow_redirect!
    expect(response.status).to eq 200
    expect(response.body).to include("先に管理画面で主催を変更します", "合同企画", business_community_path(community))
    # Business だけの会員は開けない公開画面へのリンクを出さない。
    expect(response.body).not_to include(public_event_path(event))
    expect(response.body).not_to include(edit_admin_event_path(event))
  end

  it "オーナー以外は案内ページを開けない" do
    sign_in FactoryBot.create(:customer, domain_name: "business")

    get destroy_blocked_business_community_path(community)

    expect(response).to redirect_to(business_community_path(community))
  end
end
