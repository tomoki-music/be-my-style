require "rails_helper"

RSpec.describe SingingShareImage, type: :model do
  it "expires_atを未指定の場合は7日後にする" do
    share_image = described_class.create!(
      customer: create(:customer, domain_name: "singing"),
      capture_target: "yearly-growth",
      status: :pending
    )

    expect(share_image.expires_at).to be_within(5.seconds).of(7.days.from_now)
  end

  it "completedでは画像添付を必須にする" do
    share_image = described_class.new(
      customer: create(:customer, domain_name: "singing"),
      capture_target: "yearly-growth",
      status: :completed,
      expires_at: 7.days.from_now
    )

    expect(share_image).not_to be_valid
    expect(share_image.errors[:image]).to include("must be attached when completed")
  end

  it "公開用title/descriptionはmetadataから返す" do
    share_image = build(
      :singing_share_image,
      metadata: {
        title: "公開タイトル",
        share_text: "公開説明 #BeMyStyleSinging"
      }
    )

    expect(share_image.public_title).to eq("公開タイトル")
    expect(share_image.public_description).to eq("公開説明 #BeMyStyleSinging")
  end

  it "期限切れ判定を返す" do
    share_image = build(:singing_share_image, expires_at: 1.minute.ago)

    expect(share_image).to be_expired_for_public
  end
end
