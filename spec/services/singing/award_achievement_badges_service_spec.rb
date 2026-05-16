require "rails_helper"

RSpec.describe Singing::AwardAchievementBadgesService, type: :service do
  subject(:service) { described_class.call(diagnosis) }

  let(:customer) { create(:customer, domain_name: "singing") }

  def completed_diagnosis(attrs = {})
    create(:singing_diagnosis, :completed, customer: customer, **attrs)
  end

  # update_columnsはRubyオブジェクトを更新しないのでreloadが必要
  def set_created_at(diagnosis, time)
    diagnosis.update_columns(created_at: time)
    diagnosis.reload
    diagnosis
  end

  describe "#call" do
    context "when diagnosis is not completed" do
      let(:diagnosis) { create(:singing_diagnosis, customer: customer, status: :queued) }

      it "does nothing" do
        expect { service }.not_to change(SingingAchievementBadge, :count)
      end
    end

    context "first_diagnosis" do
      # 最初の1件 → first_diagnosis + personal_best (75 > 0) が付与される
      let(:diagnosis) { completed_diagnosis(overall_score: 75) }

      it "awards first_diagnosis badge" do
        service
        expect(SingingAchievementBadge.where(customer: customer, badge_key: "first_diagnosis")).to exist
      end

      it "stores schema_version: 1 in metadata" do
        service
        badge = SingingAchievementBadge.find_by(customer: customer, badge_key: "first_diagnosis")
        expect(badge.metadata["schema_version"]).to eq(1)
      end

      it "stores diagnosis_count in metadata" do
        service
        badge = SingingAchievementBadge.find_by(customer: customer, badge_key: "first_diagnosis")
        expect(badge.metadata["diagnosis_count"]).to eq(1)
      end

      context "when already has a completed diagnosis" do
        before { completed_diagnosis }

        it "does not award first_diagnosis" do
          service
          expect(SingingAchievementBadge.where(customer: customer, badge_key: "first_diagnosis")).to be_empty
        end
      end
    end

    context "personal_best" do
      context "when score exceeds previous best" do
        before { completed_diagnosis(overall_score: 70) }
        let(:diagnosis) { completed_diagnosis(overall_score: 80) }

        it "awards personal_best badge" do
          service
          expect(SingingAchievementBadge.where(customer: customer, badge_key: "personal_best")).to exist
        end

        it "stores score delta in metadata" do
          service
          badge = SingingAchievementBadge.find_by(customer: customer, badge_key: "personal_best")
          expect(badge.metadata["score_delta"]).to eq(10)
          expect(badge.metadata["current_best_score"]).to eq(80)
        end
      end

      context "when score does not exceed previous best" do
        before { completed_diagnosis(overall_score: 85) }
        let(:diagnosis) { completed_diagnosis(overall_score: 80) }

        it "does not award personal_best" do
          service
          expect(SingingAchievementBadge.where(customer: customer, badge_key: "personal_best")).to be_empty
        end
      end
    end

    context "streak_7" do
      let(:base_date) { Date.current }

      # reloadして最新のcreated_atをRubyオブジェクトに反映させる
      let(:diagnosis) { set_created_at(completed_diagnosis, base_date.to_time) }

      context "when 7 consecutive days exist" do
        before do
          6.times do |i|
            d = completed_diagnosis
            set_created_at(d, (base_date - (i + 1).days).to_time)
          end
        end

        it "awards streak_7 badge" do
          service
          expect(SingingAchievementBadge.where(customer: customer, badge_key: "streak_7")).to exist
        end

        it "stores streak_days: 7 in metadata" do
          service
          badge = SingingAchievementBadge.find_by(customer: customer, badge_key: "streak_7")
          expect(badge.metadata["streak_days"]).to eq(7)
        end
      end

      context "when only 6 consecutive days" do
        before do
          5.times do |i|
            d = completed_diagnosis
            set_created_at(d, (base_date - (i + 1).days).to_time)
          end
        end

        it "does not award streak_7" do
          service
          expect(SingingAchievementBadge.where(customer: customer, badge_key: "streak_7")).to be_empty
        end
      end
    end

    context "streak_30" do
      let(:base_date) { Date.current }
      let(:diagnosis)  { set_created_at(completed_diagnosis, base_date.to_time) }

      context "when 30 consecutive days exist" do
        before do
          29.times do |i|
            d = completed_diagnosis
            set_created_at(d, (base_date - (i + 1).days).to_time)
          end
        end

        it "awards streak_30 badge" do
          service
          expect(SingingAchievementBadge.where(customer: customer, badge_key: "streak_30")).to exist
        end
      end

      context "when only 29 consecutive days" do
        before do
          28.times do |i|
            d = completed_diagnosis
            set_created_at(d, (base_date - (i + 1).days).to_time)
          end
        end

        it "does not award streak_30" do
          service
          expect(SingingAchievementBadge.where(customer: customer, badge_key: "streak_30")).to be_empty
        end
      end
    end

    context "first_score_90" do
      context "when score >= 90 and no prior 90+ score" do
        let(:diagnosis) { completed_diagnosis(overall_score: 91) }

        it "awards first_score_90 badge" do
          service
          expect(SingingAchievementBadge.where(customer: customer, badge_key: "first_score_90")).to exist
        end

        it "stores overall_score in metadata" do
          service
          badge = SingingAchievementBadge.find_by(customer: customer, badge_key: "first_score_90")
          expect(badge.metadata["overall_score"]).to eq(91)
        end
      end

      context "when score < 90" do
        let(:diagnosis) { completed_diagnosis(overall_score: 89) }

        it "does not award first_score_90" do
          service
          expect(SingingAchievementBadge.where(customer: customer, badge_key: "first_score_90")).to be_empty
        end
      end

      context "when prior 90+ score exists" do
        before { completed_diagnosis(overall_score: 92) }
        let(:diagnosis) { completed_diagnosis(overall_score: 91) }

        it "does not award first_score_90 again" do
          service
          expect(SingingAchievementBadge.where(customer: customer, badge_key: "first_score_90")).to be_empty
        end
      end
    end

    context "first_ranking" do
      context "when ranking_opt_in and no prior ranking diagnosis" do
        let(:diagnosis) { completed_diagnosis(ranking_opt_in: true) }

        it "awards first_ranking badge" do
          service
          expect(SingingAchievementBadge.where(customer: customer, badge_key: "first_ranking")).to exist
        end
      end

      context "when not ranking_opt_in" do
        let(:diagnosis) { completed_diagnosis(ranking_opt_in: false) }

        it "does not award first_ranking" do
          service
          expect(SingingAchievementBadge.where(customer: customer, badge_key: "first_ranking")).to be_empty
        end
      end

      context "when already has a prior ranking diagnosis" do
        before { completed_diagnosis(ranking_opt_in: true) }
        let(:diagnosis) { completed_diagnosis(ranking_opt_in: true) }

        it "does not award first_ranking again" do
          service
          expect(SingingAchievementBadge.where(customer: customer, badge_key: "first_ranking")).to be_empty
        end
      end
    end

    context "diagnosis_10" do
      context "when exactly 10 completed diagnoses" do
        before { 9.times { completed_diagnosis } }
        let(:diagnosis) { completed_diagnosis }

        it "awards diagnosis_10 badge" do
          service
          expect(SingingAchievementBadge.where(customer: customer, badge_key: "diagnosis_10")).to exist
        end
      end

      context "when 11 completed diagnoses" do
        before { 10.times { completed_diagnosis } }
        let(:diagnosis) { completed_diagnosis }

        it "does not award diagnosis_10" do
          service
          expect(SingingAchievementBadge.where(customer: customer, badge_key: "diagnosis_10")).to be_empty
        end
      end

      context "when only 9 completed diagnoses" do
        before { 8.times { completed_diagnosis } }
        let(:diagnosis) { completed_diagnosis }

        it "does not award diagnosis_10" do
          service
          expect(SingingAchievementBadge.where(customer: customer, badge_key: "diagnosis_10")).to be_empty
        end
      end
    end

    context "growth_10" do
      context "when score improved by 10+ from first diagnosis" do
        before do
          first = completed_diagnosis(overall_score: 60)
          first.update_columns(created_at: 30.days.ago)
        end
        let(:diagnosis) { completed_diagnosis(overall_score: 72) }

        it "awards growth_10 badge" do
          service
          expect(SingingAchievementBadge.where(customer: customer, badge_key: "growth_10")).to exist
        end

        it "stores growth_delta in metadata" do
          service
          badge = SingingAchievementBadge.find_by(customer: customer, badge_key: "growth_10")
          expect(badge.metadata["growth_delta"]).to eq(12)
        end
      end

      context "when score improved by only 9" do
        before do
          first = completed_diagnosis(overall_score: 70)
          first.update_columns(created_at: 30.days.ago)
        end
        let(:diagnosis) { completed_diagnosis(overall_score: 79) }

        it "does not award growth_10" do
          service
          expect(SingingAchievementBadge.where(customer: customer, badge_key: "growth_10")).to be_empty
        end
      end
    end

    context "duplicate prevention (RecordNotUnique)" do
      # first_diagnosisバッジが既にある状態で、同じ診断でserviceを呼ぶ
      # → first_diagnosisはrescueされskip、他のバッジは付与されない(2件目以降)
      let(:diagnosis) { completed_diagnosis(overall_score: 75) }

      before do
        # 手動でfirst_diagnosisバッジを先に作成
        create(:singing_achievement_badge, customer: customer,
               badge_key: "first_diagnosis", earned_at: Time.current)
        # personal_bestも作成済みにする（75点は初回なので最高スコア）
        create(:singing_achievement_badge, customer: customer,
               badge_key: "personal_best", earned_at: Time.current)
      end

      it "does not raise error" do
        expect { service }.not_to raise_error
      end

      it "does not create duplicate first_diagnosis badge" do
        service
        expect(SingingAchievementBadge.where(customer: customer, badge_key: "first_diagnosis").count).to eq(1)
      end
    end
  end
end
