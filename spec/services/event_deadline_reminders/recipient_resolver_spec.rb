require "rails_helper"

RSpec.describe EventDeadlineReminders::RecipientResolver do
  let(:owner) { FactoryBot.create(:customer) }
  let(:community) { FactoryBot.create(:community, owner_id: owner.id) }
  let(:other_community) { FactoryBot.create(:community, owner_id: owner.id) }
  let(:event) { FactoryBot.create(:event, :event_with_songs, customer: owner, community: community) }

  def member!(**attrs)
    FactoryBot.create(:customer, **attrs).tap do |customer|
      CommunityCustomer.create!(community: community, customer: customer)
    end
  end

  it "参加登録の有無を問わず、承認済みで有効なメンバーだけを返すこと" do
    not_joined = member!
    joined = member!
    JoinPartCustomer.create!(customer: joined, join_part: FactoryBot.create(:join_part, song: event.songs.first))
    withdrawn = member!(is_deleted: true)
    unconfirmed = member!
    unconfirmed.update_columns(confirmed_at: nil)
    opted_out = member!(confirm_mail: false)
    bad_email = member!
    bad_email.update_columns(email: "not-an-email")
    pending_applicant = FactoryBot.create(:customer)
    Permit.create!(community: community, customer: pending_applicant)
    outsider = FactoryBot.create(:customer)
    CommunityCustomer.create!(community: other_community, customer: outsider)

    recipients = described_class.call(event)

    expect(recipients).to contain_exactly(not_joined, joined)
    expect(recipients).not_to include(withdrawn, unconfirmed, opted_out, bad_email, pending_applicant, outsider)
  end

  it "コミュニティを退会したメンバーは送信直前の確認で対象外になること" do
    member = member!
    resolver = described_class.new(event)
    expect(resolver.eligible?(member)).to eq true

    CommunityCustomer.where(community: community, customer: member).delete_all

    expect(resolver.eligible?(member)).to eq false
  end
end
