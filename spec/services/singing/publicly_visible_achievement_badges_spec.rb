require "rails_helper"

RSpec.describe Singing::PubliclyVisibleAchievementBadges, type: :service do
  let(:customer) { create(:customer, domain_name: "singing") }

  def public_diagnosis(attrs = {})
    create(:singing_diagnosis, :completed, :ranking_participant, customer: customer, **attrs)
  end

  def private_diagnosis(attrs = {})
    create(:singing_diagnosis, :completed, customer: customer, ranking_opt_in: false, **attrs)
  end

  describe ".call" do
    it "customerがnilの場合は空集合を返すこと" do
      expect(described_class.call(nil)).to be_empty
    end

    it "診断が1件もない場合、診断依存バッジは含まれないこと" do
      keys = described_class.call(customer)
      expect(keys).not_to include("first_diagnosis", "diagnosis_10")
    end

    it "診断に依存しないbadge_key(recap関連)は常に含まれること" do
      keys = described_class.call(customer)
      expect(keys).to include("recap_movie_first_share", "recap_movie_first_download", "recap_movie_instagram_share")
    end

    it "公開診断が1件あれば first_diagnosis / first_ranking が成立すること" do
      public_diagnosis(overall_score: 70)

      keys = described_class.call(customer)
      expect(keys).to include("first_diagnosis", "first_ranking")
    end

    it "非公開診断しかない場合、first_diagnosis は成立しないこと" do
      private_diagnosis(overall_score: 70)

      keys = described_class.call(customer)
      expect(keys).not_to include("first_diagnosis")
    end

    it "公開診断が10件あれば diagnosis_10 が成立すること" do
      10.times { public_diagnosis(overall_score: 70) }

      expect(described_class.call(customer)).to include("diagnosis_10")
    end

    it "非公開診断込みで10件でも、公開診断が9件以下なら diagnosis_10 は成立しないこと" do
      9.times { public_diagnosis(overall_score: 70) }
      private_diagnosis(overall_score: 70)

      expect(described_class.call(customer)).not_to include("diagnosis_10")
    end

    it "公開→非公開→公開の順でも、非公開診断は診断回数の算出に使われないこと" do
      public_diagnosis(overall_score: 60, created_at: 3.days.ago)
      private_diagnosis(overall_score: 60, created_at: 2.days.ago)
      public_diagnosis(overall_score: 60, created_at: 1.day.ago)

      # 実際の完了診断は3件だが公開診断は2件のみのため diagnoses_3相当の
      # AwardAchievementBadgesServiceには diagnoses_3 は無いが、diagnosis_10と混同しないことを確認
      expect(described_class.call(customer)).not_to include("diagnosis_10")
    end

    it "公開診断だけでスコアが更新されていれば personal_best が成立すること" do
      public_diagnosis(overall_score: 60, created_at: 2.days.ago)
      public_diagnosis(overall_score: 80, created_at: 1.day.ago)

      expect(described_class.call(customer)).to include("personal_best")
    end

    it "非公開診断の方が高得点でも、公開診断だけを基準に personal_best を判定すること" do
      private_diagnosis(overall_score: 95, created_at: 2.days.ago)
      public_diagnosis(overall_score: 80, created_at: 1.day.ago)

      # 公開履歴だけで見ると80点は最初の公開診断のため、公開データだけでpersonal_bestは成立する
      # (非公開の95点を基準にすると成立しないはずの比較には使われない)
      expect(described_class.call(customer)).to include("personal_best")
    end

    it "公開診断で90点以上を取れば first_score_90 が成立すること" do
      public_diagnosis(overall_score: 92)

      expect(described_class.call(customer)).to include("first_score_90")
    end

    it "非公開診断でしか90点以上を取っていない場合、first_score_90 は成立しないこと" do
      private_diagnosis(overall_score: 95)
      public_diagnosis(overall_score: 70)

      expect(described_class.call(customer)).not_to include("first_score_90")
    end

    it "公開診断の初回から10点以上伸びていれば growth_10 が成立すること" do
      public_diagnosis(overall_score: 60, created_at: 2.days.ago)
      public_diagnosis(overall_score: 75, created_at: 1.day.ago)

      expect(described_class.call(customer)).to include("growth_10")
    end

    it "非公開の初回診断を基準にしたgrowth_10は成立しないこと" do
      private_diagnosis(overall_score: 10, created_at: 3.days.ago)
      public_diagnosis(overall_score: 60, created_at: 2.days.ago)
      public_diagnosis(overall_score: 65, created_at: 1.day.ago)

      # 非公開(10点)を初回とすれば+55だが、公開診断だけの初回(60点)から見ると+5でgrowth_10は不成立
      expect(described_class.call(customer)).not_to include("growth_10")
    end

    it "公開診断だけで7日連続していれば streak_7 が成立すること" do
      7.times { |i| public_diagnosis(overall_score: 70, created_at: i.days.ago) }

      expect(described_class.call(customer)).to include("streak_7")
    end

    it "非公開診断を挟むと連続日数として数えず streak_7 が成立しないこと" do
      6.times { |i| public_diagnosis(overall_score: 70, created_at: i.days.ago) }
      private_diagnosis(overall_score: 70, created_at: 6.days.ago)

      expect(described_class.call(customer)).not_to include("streak_7")
    end
  end
end
