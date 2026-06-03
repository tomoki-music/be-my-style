require "rails_helper"

RSpec.describe Singing::MusicCommunityHomeBuilder do
  describe ".call" do
    let(:customer) { create(:customer, domain_name: "singing") }

    it "customer nilでも生成される" do
      home = described_class.call(nil)

      expect(home).to be_a(described_class::MusicCommunityHome)
      expect(home.hero_message).to be_present
      expect(home.today_mission).to be_present
      expect(home.gentle_return_flow).to be_present
      expect(home.community_memory).to be_present
      expect(home.community_recommendation).to be_present
      expect(home.return_motivation).to be_present
      expect(home.music_friends).to be_present
      expect(home.friend_activity_highlights).to be_present
      expect(home.community_network).to be_present
      expect(home.suggested_musicians).to be_present
      expect(home.community_summary).to be_present
      expect(home.recommended_event).to be_present
      expect(home.growth_summary).to be_present
    end

    it "DTOを返し、ホームに必要な主要要素が空にならない" do
      home = described_class.call(customer)

      expect(home).to be_a(described_class::MusicCommunityHome)
      expect(home.hero_message).to be_present
      expect(home.today_mission).to be_a(Singing::MissionGenerator::Mission)
      expect(home.gentle_return_flow).to be_a(Singing::GentleReturnFlowBuilder::Result)
      expect(home.community_memory).to be_a(Singing::CommunityMemoryBuilder::Result)
      expect(home.community_recommendation).to be_a(Singing::CommunityRecommendationBuilder::Result)
      expect(home.return_motivation).to be_a(Singing::ReturnMotivationBuilder::ReturnMotivation)
      expect(home.music_friends).to be_a(Singing::MusicFriendsBuilder::Result)
      expect(home.friend_activity_highlights).to be_a(Singing::FriendActivityHighlightsBuilder::Result)
      expect(home.community_network).to be_a(Singing::CommunityNetworkBuilder::CommunityNetwork)
      expect(home.suggested_musicians).to be_a(Singing::SuggestedMusiciansBuilder::SuggestedMusicians)
      expect(home.community_summary.items).to be_present
      expect(home.recommended_event.items).to be_present
      expect(home.growth_summary.items).to be_present
    end

    it "growth_partnerships が GrowthPartnershipsResult を返す" do
      home = described_class.call(customer)

      expect(home.growth_partnerships).to be_a(Singing::GrowthPartnershipsBuilder::GrowthPartnershipsResult)
    end

    it "growth_partnerships.message が存在する" do
      home = described_class.call(customer)

      expect(home.growth_partnerships.message).to be_present
    end

    it "music_social_graph が MusicSocialGraph を返す" do
      home = described_class.call(customer)

      expect(home.music_social_graph).to be_a(Singing::MusicSocialGraphBuilder::MusicSocialGraph)
    end

    it "music_social_graph.graph_message が存在する" do
      home = described_class.call(customer)

      expect(home.music_social_graph.graph_message).to be_present
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

    it "gentle_return_flow を統合して返す" do
      create(:singing_diagnosis, :completed, customer: customer, created_at: 30.days.ago)

      home = described_class.call(customer)

      expect(home.gentle_return_flow).to be_a(Singing::GentleReturnFlowBuilder::Result)
      expect(home.gentle_return_flow).to be_active
      expect(home.gentle_return_flow.absence_level).to eq(:long_absence)
    end

    describe "home_cta" do
      it "HomeCta を返す" do
        home = described_class.call(customer)

        expect(home.home_cta).to be_a(described_class::HomeCta)
      end

      it "nil customerでは無料登録CTAを返す" do
        home = described_class.call(nil)

        expect(home.home_cta.primary_label).to eq("無料で始める")
      end

      it "診断0件では最初の診断CTAを返す" do
        home = described_class.call(customer)

        expect(home.home_cta.primary_label).to eq("最初の診断をする")
      end

      it "診断1〜2件ではミッションCTAを返す" do
        create(:singing_diagnosis, :completed, customer: customer)
        create(:singing_diagnosis, :completed, customer: customer)

        home = described_class.call(customer)

        expect(home.home_cta.primary_label).to eq("今日のミッションを見る")
      end

      it "診断3件以上では成長レポートCTAを返す" do
        3.times { create(:singing_diagnosis, :completed, customer: customer) }

        home = described_class.call(customer)

        expect(home.home_cta.primary_label).to eq("成長レポートを見る")
      end

      it "全状態でsecondary_labelが存在する" do
        home = described_class.call(customer)

        expect(home.home_cta.secondary_label).to be_present
      end

      it "全状態でmessageが存在する" do
        home = described_class.call(customer)

        expect(home.home_cta.message).to be_present
      end
    end
  end
end
