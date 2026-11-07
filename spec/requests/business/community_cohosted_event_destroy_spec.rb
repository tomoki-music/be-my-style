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

  it "共催イベントを主催していると削除できず、対象イベントを案内する" do
    expect { delete business_community_path(community) }.not_to change(Community, :count)

    expect(response).to redirect_to(business_community_path(community))
    expect(flash[:alert]).to include("先に対象イベントの主催コミュニティを変更してください", "「合同企画」(ID: #{event.id})")
  end
end
