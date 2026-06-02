require "rails_helper"

RSpec.describe Singing::CommunityReputationBuilder do
  def create_event_participation(for_customer:)
    event = build(:event)
    song = build(:song, event: event)
    event.songs = [song]
    event.save!
    song.save!
    join_part = create(:join_part, song: song)
    create(:join_part_customer, customer: for_customer, join_part: join_part)
  end

  def create_challenge_progress(customer:, days_ago: 1)
    challenge = create(:singing_daily_challenge, challenge_date: days_ago.days.ago.to_date)
    create(:singing_daily_challenge_progress, customer: customer, singing_daily_challenge: challenge, completed_at: days_ago.days.ago)
  end

  describe ".call" do
    subject(:reputation) { described_class.call(customer: customer) }

    let(:customer) { create(:customer, domain_name: "singing") }

    it "CommunityReputation DTOを返す" do
      expect(reputation).to be_a(described_class::CommunityReputation)
    end

    it "nil customer で nil を返す" do
      expect(described_class.call(customer: nil)).to be_nil
    end

    it "全属性が存在する" do
      expect(reputation.reputation_level).to be_present
      expect(reputation.reputation_title).to be_present
      expect(reputation.reputation_points).not_to be_nil
      expect(reputation.streak_points).not_to be_nil
      expect(reputation.challenge_points).not_to be_nil
      expect(reputation.cheer_points).not_to be_nil
      expect(reputation.participation_points).not_to be_nil
      expect(reputation.next_level_points).not_to be_nil
      expect(reputation.progress_percent).not_to be_nil
      expect(reputation.reputation_message).to be_present
    end

    describe "streak_points（継続ポイント）" do
      it "データなしで 0 を返す" do
        expect(reputation.streak_points).to eq(0)
      end

      it "completed診断 1 回 = 1pt" do
        create(:singing_diagnosis, :completed, customer: customer)

        expect(reputation.streak_points).to eq(1)
      end

      it "completed診断 3 回 = 3pt" do
        create_list(:singing_diagnosis, 3, :completed, customer: customer)

        expect(reputation.streak_points).to eq(3)
      end

      it "未完了の診断はカウントしない" do
        create(:singing_diagnosis, customer: customer)

        expect(reputation.streak_points).to eq(0)
      end
    end

    describe "cheer_points（応援ポイント）" do
      it "データなしで 0 を返す" do
        expect(reputation.cheer_points).to eq(0)
      end

      it "応援 1 回 = 2pt" do
        target = create(:customer, domain_name: "singing")
        create(:singing_cheer_reaction, customer: customer, target_customer: target)

        expect(reputation.cheer_points).to eq(2)
      end

      it "応援 3 回 = 6pt" do
        3.times do
          target = create(:customer, domain_name: "singing")
          create(:singing_cheer_reaction, customer: customer, target_customer: target)
        end

        expect(reputation.cheer_points).to eq(6)
      end
    end

    describe "challenge_points（挑戦ポイント）" do
      it "データなしで 0 を返す" do
        expect(reputation.challenge_points).to eq(0)
      end

      it "チャレンジ達成 1 回 = 5pt" do
        create_challenge_progress(customer: customer, days_ago: 3)

        expect(reputation.challenge_points).to eq(5)
      end

      it "チャレンジ達成 2 回 = 10pt" do
        create_challenge_progress(customer: customer, days_ago: 1)
        create_challenge_progress(customer: customer, days_ago: 2)

        expect(reputation.challenge_points).to eq(10)
      end

      it "completed_at が nil のものはカウントしない" do
        challenge = create(:singing_daily_challenge, challenge_date: Date.current)
        create(:singing_daily_challenge_progress, customer: customer, singing_daily_challenge: challenge, completed_at: nil)

        expect(reputation.challenge_points).to eq(0)
      end
    end

    describe "participation_points（参加ポイント）" do
      it "データなしで 0 を返す" do
        expect(reputation.participation_points).to eq(0)
      end

      it "参加 1 回 = 3pt" do
        create_event_participation(for_customer: customer)

        expect(reputation.participation_points).to eq(3)
      end

      it "参加 2 回 = 6pt" do
        create_event_participation(for_customer: customer)
        create_event_participation(for_customer: customer)

        expect(reputation.participation_points).to eq(6)
      end
    end

    describe "reputation_points（合計）" do
      it "各ポイントの合計を返す" do
        target = create(:customer, domain_name: "singing")
        create(:singing_diagnosis, :completed, customer: customer)                    # 1pt
        create(:singing_cheer_reaction, customer: customer, target_customer: target)  # 2pt
        create_challenge_progress(customer: customer, days_ago: 1)                    # 5pt

        expect(reputation.reputation_points).to eq(8)
        expect(reputation.streak_points).to eq(1)
        expect(reputation.cheer_points).to eq(2)
        expect(reputation.challenge_points).to eq(5)
      end

      it "データなしで 0 を返す" do
        expect(reputation.reputation_points).to eq(0)
      end
    end

    describe "reputation_level / reputation_title" do
      context "0pt (Seed)" do
        it "Seed レベルを返す" do
          expect(reputation.reputation_level).to eq(:seed)
          expect(reputation.reputation_title).to eq("🌱 Seed")
        end
      end

      context "50pt (Supporter)" do
        it "Supporter レベルを返す" do
          create_list(:singing_diagnosis, 50, :completed, customer: customer)

          expect(reputation.reputation_level).to eq(:supporter)
          expect(reputation.reputation_title).to eq("🤝 Supporter")
        end
      end

      context "150pt (Performer)" do
        it "Performer レベルを返す" do
          create_list(:singing_diagnosis, 150, :completed, customer: customer)

          expect(reputation.reputation_level).to eq(:performer)
          expect(reputation.reputation_title).to eq("🎤 Performer")
        end
      end

      context "300pt (Community Star)" do
        it "Community Star レベルを返す" do
          create_list(:singing_diagnosis, 300, :completed, customer: customer)

          expect(reputation.reputation_level).to eq(:community_star)
          expect(reputation.reputation_title).to eq("⭐ Community Star")
        end
      end

      context "600pt (Music Partner)" do
        it "Music Partner レベルを返す" do
          create_list(:singing_diagnosis, 600, :completed, customer: customer)

          expect(reputation.reputation_level).to eq(:music_partner)
          expect(reputation.reputation_title).to eq("🎵 Music Partner")
        end
      end

      context "1000pt (Music Ambassador)" do
        it "Music Ambassador レベルを返す" do
          create_list(:singing_diagnosis, 1000, :completed, customer: customer)

          expect(reputation.reputation_level).to eq(:music_ambassador)
          expect(reputation.reputation_title).to eq("👑 Music Ambassador")
        end
      end
    end

    describe "next_level_points" do
      it "Seed (0pt) → Supporter まで 50pt" do
        expect(reputation.next_level_points).to eq(50)
      end

      it "途中のレベルで残りポイントを返す" do
        create_list(:singing_diagnosis, 75, :completed, customer: customer)

        expect(reputation.next_level_points).to eq(75) # 150 - 75
      end

      it "最大レベル (Music Ambassador) で 0 を返す" do
        create_list(:singing_diagnosis, 1000, :completed, customer: customer)

        expect(reputation.next_level_points).to eq(0)
      end
    end

    describe "progress_percent" do
      it "データなし (0pt, Seed) で 0% を返す" do
        expect(reputation.progress_percent).to eq(0)
      end

      it "Seed の中間 (25pt) で 50% を返す" do
        create_list(:singing_diagnosis, 25, :completed, customer: customer)

        expect(reputation.progress_percent).to eq(50)
      end

      it "最大レベル (Music Ambassador) で 100% を返す" do
        create_list(:singing_diagnosis, 1000, :completed, customer: customer)

        expect(reputation.progress_percent).to eq(100)
      end

      it "0〜100 の範囲に収まる" do
        create_list(:singing_diagnosis, 2000, :completed, customer: customer)

        expect(reputation.progress_percent).to be_between(0, 100)
      end
    end

    describe "reputation_message" do
      it "Seed メッセージを返す" do
        expect(reputation.reputation_message).to eq("あなたの一歩がコミュニティを育てています🌱")
      end

      it "Supporter メッセージを返す" do
        create_list(:singing_diagnosis, 50, :completed, customer: customer)

        expect(reputation.reputation_message).to eq("仲間への応援が広がっています🤝")
      end

      it "Music Ambassador メッセージを返す" do
        create_list(:singing_diagnosis, 1000, :completed, customer: customer)

        expect(reputation.reputation_message).to eq("多くの仲間へ良い影響を届けています👑")
      end
    end
  end
end
