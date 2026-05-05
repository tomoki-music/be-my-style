require "rails_helper"

RSpec.describe SingingProfileReaction, type: :model do
  it "同じユーザー・同じプロフィール・同じリアクション種別の重複を許可しないこと" do
    reaction = create(:singing_profile_reaction)
    duplicate = build(
      :singing_profile_reaction,
      customer: reaction.customer,
      target_customer: reaction.target_customer,
      reaction_type: reaction.reaction_type
    )

    expect(duplicate).not_to be_valid
  end

  it "自分のプロフィールにはリアクションできないこと" do
    customer = create(:customer, domain_name: "singing")
    reaction = build(:singing_profile_reaction, customer: customer, target_customer: customer)

    expect(reaction).not_to be_valid
  end

  it "定義済みリアクション以外は許可しないこと" do
    reaction = build(:singing_profile_reaction, reaction_type: "negative")

    expect(reaction).not_to be_valid
  end
end
