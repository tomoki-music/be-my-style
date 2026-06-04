require "rails_helper"

RSpec.describe Singing::MusicMilestonesBuilder do
  describe ".call" do
    let(:customer) { create(:customer, domain_name: "singing") }

    it "nil customerではinactiveを返す" do
      result = described_class.call(nil)

      expect(result).not_to be_active
      expect(result.milestones).to eq([])
    end

    it "活動がない場合はinactiveを返す" do
      result = described_class.call(customer)

      expect(result).not_to be_active
      expect(result.milestones).to eq([])
    end

    it "初回診断のマイルストーンを返す" do
      create(:singing_diagnosis, :completed, customer: customer)

      result = described_class.call(customer)

      expect(result).to be_active
      first = result.milestones.find { |m| m.title == "First Diagnosis" }
      expect(first).to be_present
      expect(first.icon).to eq("🎤")
      expect(first.message).to eq("初めて歌唱診断を行いました")
      expect(first.occurred_at).to be_present
    end

    it "10回診断達成のマイルストーンを返す" do
      10.times { create(:singing_diagnosis, :completed, customer: customer) }

      result = described_class.call(customer)

      expect(result.milestones.map(&:title)).to include("Diagnosis Explorer")
    end

    it "9回の診断ではDiagnosis Explorerを返さない" do
      9.times { create(:singing_diagnosis, :completed, customer: customer) }

      result = described_class.call(customer)

      expect(result.milestones.map(&:title)).not_to include("Diagnosis Explorer")
    end

    it "初めて応援したマイルストーンを返す" do
      target = create(:customer, domain_name: "singing")
      create(:singing_cheer_reaction, customer: customer, target_customer: target)

      result = described_class.call(customer)

      first_cheer = result.milestones.find { |m| m.title == "First Cheer" }
      expect(first_cheer).to be_present
      expect(first_cheer.icon).to eq("👏")
      expect(first_cheer.message).to eq("初めて仲間を応援しました")
    end

    it "初めて応援されたマイルストーンを返す" do
      sender = create(:customer, domain_name: "singing")
      create(:singing_cheer_reaction, customer: sender, target_customer: customer)

      result = described_class.call(customer)

      first_enc = result.milestones.find { |m| m.title == "First Encouragement" }
      expect(first_enc).to be_present
      expect(first_enc.icon).to eq("🎉")
      expect(first_enc.message).to eq("初めて仲間から応援されました")
    end

    it "初めてチャレンジ参加のマイルストーンを返す（AIチャレンジ）" do
      create(:singing_ai_challenge_progress, customer: customer, tried: true)

      result = described_class.call(customer)

      first_challenge = result.milestones.find { |m| m.title == "First Challenge" }
      expect(first_challenge).to be_present
      expect(first_challenge.icon).to eq("🏆")
    end

    it "初めてチャレンジ参加のマイルストーンを返す（デイリーチャレンジ）" do
      create(:singing_daily_challenge_progress, customer: customer)

      result = described_class.call(customer)

      first_challenge = result.milestones.find { |m| m.title == "First Challenge" }
      expect(first_challenge).to be_present
    end

    it "7日継続のマイルストーンを返す" do
      7.times do |i|
        create(:singing_diagnosis, :completed, customer: customer, created_at: i.days.ago)
      end

      result = described_class.call(customer)

      consistency = result.milestones.find { |m| m.title == "Consistency" }
      expect(consistency).to be_present
      expect(consistency.icon).to eq("🎵")
      expect(consistency.message).to eq("7日間の継続を達成しました")
    end

    it "6日の診断ではConsistencyを返さない" do
      6.times do |i|
        create(:singing_diagnosis, :completed, customer: customer, created_at: i.days.ago)
      end

      result = described_class.call(customer)

      expect(result.milestones.map(&:title)).not_to include("Consistency")
    end

    it "複数のマイルストーンをまとめて返す" do
      create(:singing_diagnosis, :completed, customer: customer)
      target = create(:customer, domain_name: "singing")
      create(:singing_cheer_reaction, customer: customer, target_customer: target)

      result = described_class.call(customer)

      titles = result.milestones.map(&:title)
      expect(titles).to include("First Diagnosis", "First Cheer")
    end

    it "マイルストーンを最大3件に制限する" do
      10.times { |i| create(:singing_diagnosis, :completed, customer: customer, created_at: i.days.ago) }
      target = create(:customer, domain_name: "singing")
      sender = create(:customer, domain_name: "singing")
      create(:singing_cheer_reaction, customer: customer, target_customer: target)
      create(:singing_cheer_reaction, customer: sender, target_customer: customer)
      create(:singing_ai_challenge_progress, customer: customer, tried: true)

      result = described_class.call(customer)

      expect(result.milestones.size).to eq(3)
    end

    it "マイルストーンが最新順に並ぶ" do
      create(:singing_diagnosis, :completed, customer: customer, created_at: 10.days.ago)
      target = create(:customer, domain_name: "singing")
      create(:singing_cheer_reaction, customer: customer, target_customer: target, created_at: 2.days.ago)

      result = described_class.call(customer)

      occurred_ats = result.milestones.map(&:occurred_at)
      expect(occurred_ats).to eq(occurred_ats.sort.reverse)
    end

    it "各マイルストーンにoccurred_atが設定される" do
      create(:singing_diagnosis, :completed, customer: customer)

      result = described_class.call(customer)

      result.milestones.each do |m|
        expect(m.occurred_at).to be_present
      end
    end
  end
end
