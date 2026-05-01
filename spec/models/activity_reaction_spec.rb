require 'rails_helper'

RSpec.describe ActivityReaction, type: :model do
  let(:customer) { create(:customer) }
  let(:activity) { create(:activity) }

  describe "バリデーション" do
    it "有効なreaction_typeで保存できること" do
      ActivityReaction::REACTION_TYPES.each do |type|
        reaction = build(:activity_reaction, customer: customer, activity: activity, reaction_type: type)
        expect(reaction).to be_valid, "#{type} は有効なはず"
      end
    end

    it "無効なreaction_typeは保存できないこと" do
      reaction = build(:activity_reaction, customer: customer, activity: activity, reaction_type: "invalid")
      expect(reaction).not_to be_valid
    end

    it "同一ユーザー・同一活動・同一reaction_typeは重複できないこと" do
      create(:activity_reaction, customer: customer, activity: activity, reaction_type: "fire")
      duplicate = build(:activity_reaction, customer: customer, activity: activity, reaction_type: "fire")
      expect(duplicate).not_to be_valid
    end

    it "同一ユーザー・同一活動でも異なるreaction_typeは保存できること" do
      create(:activity_reaction, customer: customer, activity: activity, reaction_type: "fire")
      another = build(:activity_reaction, customer: customer, activity: activity, reaction_type: "clap")
      expect(another).to be_valid
    end

    it "同一活動・同一reaction_typeでも別ユーザーは保存できること" do
      other_customer = create(:customer)
      create(:activity_reaction, customer: customer, activity: activity, reaction_type: "fire")
      other_reaction = build(:activity_reaction, customer: other_customer, activity: activity, reaction_type: "fire")
      expect(other_reaction).to be_valid
    end
  end

  describe "アソシエーション" do
    it "customerに属すること" do
      expect(ActivityReaction.reflect_on_association(:customer).macro).to eq :belongs_to
    end

    it "activityに属すること" do
      expect(ActivityReaction.reflect_on_association(:activity).macro).to eq :belongs_to
    end
  end

  describe "REACTION_TYPES定数" do
    it "fire/clap/guitar/micを含むこと" do
      expect(ActivityReaction::REACTION_TYPES).to include("fire", "clap", "guitar", "mic")
    end
  end
end
