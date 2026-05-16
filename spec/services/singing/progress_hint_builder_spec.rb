require "rails_helper"

RSpec.describe Singing::ProgressHintBuilder do
  let(:customer) { create(:customer, domain_name: "singing") }
  let(:earned_keys) { Set.new }

  def call(keys = earned_keys)
    described_class.call(customer, earned_badge_keys: keys)
  end

  def completed_diag(score: 75, created_at: Time.current)
    create(:singing_diagnosis, :completed, customer: customer,
           overall_score: score, created_at: created_at)
  end

  describe ".call" do
    context "診断が1件もない場合" do
      it "progress_ratioが0のhintを返すこと（diagnosis_10）" do
        hints = call
        d10 = hints.find { |h| h.badge_key == "diagnosis_10" }
        expect(d10).not_to be_nil
        expect(d10.progress_ratio).to eq 0.0
      end
    end

    context "獲得済みバッジはhint対象外" do
      it "diagnosis_10 が earned_keys にあれば返さないこと" do
        hints = call(Set.new(%w[diagnosis_10]))
        expect(hints.map(&:badge_key)).not_to include("diagnosis_10")
      end

      it "streak_7 が earned_keys にあれば返さないこと" do
        hints = call(Set.new(%w[streak_7]))
        expect(hints.map(&:badge_key)).not_to include("streak_7")
      end
    end

    describe "diagnosis_10 hint" do
      it "3回診断済みで正しいprogress_ratioと文言を返すこと" do
        3.times { completed_diag }
        hints = call
        h = hints.find { |x| x.badge_key == "diagnosis_10" }
        expect(h.progress_ratio).to eq(3.0 / 10)
        expect(h.hint_text).to eq "あと7回で「10 Songs」"
        expect(h.detail_text).to eq "累計3回 / 目標10回"
        expect(h.current_value).to eq 3
        expect(h.target_value).to eq 10
      end

      it "9回診断済みでratio=0.9になること" do
        9.times { completed_diag }
        h = call.find { |x| x.badge_key == "diagnosis_10" }
        expect(h.progress_ratio).to be_within(0.01).of(0.9)
        expect(h.hint_text).to include("あと1回")
      end

      it "10回以上でratio=1.0のためnilを返すこと" do
        10.times { completed_diag }
        h = call.find { |x| x.badge_key == "diagnosis_10" }
        expect(h).to be_nil
      end
    end

    describe "streak_7 hint" do
      it "連続5日でratio = 5/7 を返すこと" do
        5.times { |i| completed_diag(created_at: (4 - i).days.ago) }
        h = call.find { |x| x.badge_key == "streak_7" }
        expect(h.progress_ratio).to be_within(0.01).of(5.0 / 7)
        expect(h.hint_text).to eq "あと2日で「7 Day Streak」"
        expect(h.detail_text).to eq "5日連続 / 目標7日"
      end

      it "streak=0のとき ratio=0.0 を返すこと" do
        h = call.find { |x| x.badge_key == "streak_7" }
        expect(h.progress_ratio).to eq 0.0
      end
    end

    describe "streak_30 hint" do
      it "連続20日でratio = 20/30 を返すこと" do
        20.times { |i| completed_diag(created_at: (19 - i).days.ago) }
        h = call.find { |x| x.badge_key == "streak_30" }
        expect(h.progress_ratio).to be_within(0.01).of(20.0 / 30)
        expect(h.hint_text).to eq "あと10日で「Monthly Devotee」"
      end
    end

    describe "first_score_90 hint" do
      it "best_score=85のとき ratio=85/90 を返すこと" do
        completed_diag(score: 85)
        h = call.find { |x| x.badge_key == "first_score_90" }
        expect(h.progress_ratio).to be_within(0.01).of(85.0 / 90)
        expect(h.hint_text).to eq "あと5点で「Score 90 Club」"
        expect(h.detail_text).to eq "85点 / 目標90点"
      end

      it "best_score=0のとき ratio=0.0 を返すこと" do
        h = call.find { |x| x.badge_key == "first_score_90" }
        expect(h.progress_ratio).to eq 0.0
      end

      it "best_score>=90のときnilを返すこと" do
        completed_diag(score: 91)
        h = call.find { |x| x.badge_key == "first_score_90" }
        expect(h).to be_nil
      end
    end

    describe "growth_10 hint" do
      it "診断がない場合はnilを返すこと" do
        h = call.find { |x| x.badge_key == "growth_10" }
        expect(h).to be_nil
      end

      it "初回50点→現在57点でratio=7/10 を返すこと" do
        completed_diag(score: 50, created_at: 10.days.ago)
        completed_diag(score: 57)
        h = call.find { |x| x.badge_key == "growth_10" }
        expect(h.progress_ratio).to be_within(0.01).of(7.0 / 10)
        expect(h.hint_text).to eq "あと3点成長で「Rising Star」"
        expect(h.detail_text).to eq "+7点成長 / 目標+10点"
      end

      it "初回50点→現在60点以上でnilを返すこと" do
        completed_diag(score: 50, created_at: 10.days.ago)
        completed_diag(score: 61)
        h = call.find { |x| x.badge_key == "growth_10" }
        expect(h).to be_nil
      end
    end

    it "hint_badge_keys にない personal_best などは返さないこと" do
      hints = call
      expect(hints.map(&:badge_key)).not_to include("personal_best", "first_ranking", "first_diagnosis")
    end
  end
end
