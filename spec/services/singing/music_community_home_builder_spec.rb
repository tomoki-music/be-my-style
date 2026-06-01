require "rails_helper"

RSpec.describe Singing::MusicCommunityHomeBuilder do
  describe ".call" do
    let(:customer) { create(:customer, domain_name: "singing") }

    it "customer nilでも生成される" do
      home = described_class.call(nil)

      expect(home).to be_a(described_class::MusicCommunityHome)
      expect(home.hero_message).to be_present
      expect(home.today_mission).to be_present
      expect(home.community_network).to be_present
      expect(home.community_summary).to be_present
      expect(home.recommended_event).to be_present
      expect(home.growth_summary).to be_present
    end

    it "DTOを返し、ホームに必要な主要要素が空にならない" do
      home = described_class.call(customer)

      expect(home).to be_a(described_class::MusicCommunityHome)
      expect(home.hero_message).to be_present
      expect(home.today_mission).to be_a(Singing::MissionGenerator::Mission)
      expect(home.community_network).to be_a(Singing::CommunityNetworkBuilder::CommunityNetwork)
      expect(home.community_summary.items).to be_present
      expect(home.recommended_event.items).to be_present
      expect(home.growth_summary.items).to be_present
    end

    it "診断0件では最初の一歩向けのhero_messageを返す" do
      home = described_class.call(customer)

      expect(home.hero_message).to eq("最初の一歩を踏み出そう")
    end

    it "診断済みユーザーでは継続中のhero_messageを返す" do
      create(:singing_diagnosis, :completed, customer: customer)

      home = described_class.call(customer)

      expect(home.hero_message).to eq("今日も少しずつ成長しています")
    end

    it "nil安全" do
      expect { described_class.call(nil) }.not_to raise_error
    end
  end
end
