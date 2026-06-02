require "rails_helper"

RSpec.describe Singing::MusicCommunityEcosystemBuilder do
  describe ".call" do
    subject(:ecosystem) { described_class.call(customer: customer) }

    let(:customer) { create(:customer, domain_name: "singing") }

    it "MusicCommunityEcosystem DTOを返す" do
      expect(ecosystem).to be_a(described_class::MusicCommunityEcosystem)
    end

    it "nil customerでも正常に生成される" do
      expect { described_class.call(customer: nil) }.not_to raise_error
    end

    it "nil customerでもDTOを返す" do
      result = described_class.call(customer: nil)

      expect(result).to be_a(described_class::MusicCommunityEcosystem)
    end

    it "全属性が存在する" do
      expect(ecosystem.active_members_count).not_to be_nil
      expect(ecosystem.active_circles_count).not_to be_nil
      expect(ecosystem.weekly_cheers_count).not_to be_nil
      expect(ecosystem.weekly_challenges_count).not_to be_nil
      expect(ecosystem.ecosystem_message).to be_present
    end

    describe "active_members_count" do
      it "データなしで0を返す" do
        expect(ecosystem.active_members_count).to eq(0)
      end

      it "直近7日以内のcompleted診断を持つユーザーをカウントする" do
        create(:singing_diagnosis, :completed, customer: customer, created_at: 3.days.ago)

        expect(ecosystem.active_members_count).to eq(1)
      end

      it "同一ユーザーの複数診断はdistinctでカウントする" do
        create(:singing_diagnosis, :completed, customer: customer, created_at: 3.days.ago)
        create(:singing_diagnosis, :completed, customer: customer, created_at: 1.day.ago)

        expect(ecosystem.active_members_count).to eq(1)
      end

      it "7日より前の診断は含まない" do
        create(:singing_diagnosis, :completed, customer: customer, created_at: 8.days.ago)

        expect(ecosystem.active_members_count).to eq(0)
      end

      it "複数ユーザーを正しくカウントする" do
        other = create(:customer, domain_name: "singing")
        create(:singing_diagnosis, :completed, customer: customer, created_at: 2.days.ago)
        create(:singing_diagnosis, :completed, customer: other, created_at: 1.day.ago)

        expect(ecosystem.active_members_count).to eq(2)
      end
    end

    describe "active_circles_count" do
      it "正の数を返す（GrowthCirclesBuilder の設定ベース）" do
        expect(ecosystem.active_circles_count).to be > 0
      end

      it "GrowthCirclesBuilder の全サークル設定を含む数を返す" do
        expected = Singing::GrowthCirclesBuilder::GROWTH_TYPE_CIRCLES.count +
                   Singing::GrowthCirclesBuilder::MISSION_CIRCLES.count +
                   1 # CHEER_CIRCLE_CONFIG

        expect(ecosystem.active_circles_count).to eq(expected)
      end
    end

    describe "weekly_cheers_count" do
      it "データなしで0を返す" do
        expect(ecosystem.weekly_cheers_count).to eq(0)
      end

      it "直近7日以内のcheer reactionをカウントする" do
        target = create(:customer, domain_name: "singing")
        create(:singing_cheer_reaction, customer: customer, target_customer: target, created_at: 2.days.ago)

        expect(ecosystem.weekly_cheers_count).to eq(1)
      end

      it "7日より前のcheer reactionは含まない" do
        target = create(:customer, domain_name: "singing")
        create(:singing_cheer_reaction, customer: customer, target_customer: target, created_at: 8.days.ago)

        expect(ecosystem.weekly_cheers_count).to eq(0)
      end

      it "全ユーザーのcheer reactionを集計する" do
        other = create(:customer, domain_name: "singing")
        target = create(:customer, domain_name: "singing")
        create(:singing_cheer_reaction, customer: customer, target_customer: target, created_at: 1.day.ago)
        create(:singing_cheer_reaction, customer: other, target_customer: target, created_at: 1.day.ago)

        expect(ecosystem.weekly_cheers_count).to eq(2)
      end
    end

    describe "weekly_challenges_count" do
      it "データなしで0を返す" do
        expect(ecosystem.weekly_challenges_count).to eq(0)
      end

      it "直近7日以内のchallenge完了をカウントする" do
        create(:singing_daily_challenge_progress, customer: customer, completed_at: 2.days.ago)

        expect(ecosystem.weekly_challenges_count).to eq(1)
      end

      it "7日より前のchallenge完了は含まない" do
        create(:singing_daily_challenge_progress, customer: customer, completed_at: 8.days.ago)

        expect(ecosystem.weekly_challenges_count).to eq(0)
      end

      it "completed_atがnilのものは含まない" do
        create(:singing_daily_challenge_progress, customer: customer, completed_at: nil)

        expect(ecosystem.weekly_challenges_count).to eq(0)
      end
    end

    describe "ecosystem_message" do
      context "active_members_count が 50 以上" do
        it "「今週もたくさんの仲間...」メッセージを返す" do
          50.times do
            c = create(:customer, domain_name: "singing")
            create(:singing_diagnosis, :completed, customer: c, created_at: 1.day.ago)
          end

          expect(ecosystem.ecosystem_message).to eq("今週もたくさんの仲間が歌を楽しんでいます🎵")
        end
      end

      context "active_members_count が 20 以上 50 未満" do
        it "「仲間たちの挑戦が...」メッセージを返す" do
          20.times do
            c = create(:customer, domain_name: "singing")
            create(:singing_diagnosis, :completed, customer: c, created_at: 1.day.ago)
          end

          expect(ecosystem.ecosystem_message).to eq("仲間たちの挑戦がコミュニティを盛り上げています✨")
        end
      end

      context "active_members_count が 20 未満" do
        it "「あなたの一歩が...」メッセージを返す" do
          expect(ecosystem.ecosystem_message).to eq("あなたの一歩がコミュニティを育てています🌱")
        end
      end
    end
  end
end
