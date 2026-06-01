require "rails_helper"

RSpec.describe Singing::CoachLetterBuilder do
  let(:customer) { create(:customer, domain_name: "singing", singing_coach_personality: :passionate) }

  def diagnosis_at(days_ago, overall: 75, pitch: 70, rhythm: 70, expression: 70)
    ts = days_ago.days.ago
    create(:singing_diagnosis, :completed,
           customer:         customer,
           overall_score:    overall,
           pitch_score:      pitch,
           rhythm_score:     rhythm,
           expression_score: expression,
           created_at:       ts,
           diagnosed_at:     ts)
  end

  describe ".call" do
    context "customer が nil の場合" do
      it "has_letter: false を返す" do
        result = described_class.call(nil)
        expect(result.has_letter).to be false
      end
    end

    context "診断が 0 件の場合" do
      it "has_letter: false を返す" do
        expect(described_class.call(customer).has_letter).to be false
      end
    end

    context "診断が 1 件の場合" do
      before { diagnosis_at(7) }

      it "has_letter: true を返す" do
        expect(described_class.call(customer).has_letter).to be true
      end

      it "各セクションが文字列を返すこと" do
        result = described_class.call(customer)
        expect(result.greeting).to      be_a(String).and be_present
        expect(result.introduction).to  be_a(String).and be_present
        expect(result.journey).to       be_a(String).and be_present
        expect(result.growth).to        be_a(String).and be_present
        expect(result.encouragement).to be_a(String).and be_present
      end

      it "coach_label と coach_icon が設定されること" do
        result = described_class.call(customer)
        expect(result.coach_label).to be_present
        expect(result.coach_icon).to  be_present
      end

      it "personality が passionate であること" do
        expect(described_class.call(customer).personality).to eq "passionate"
      end

      it "generated_at が Time であること" do
        expect(described_class.call(customer).generated_at).to be_a(Time)
      end
    end

    context "診断が複数ある場合" do
      before do
        diagnosis_at(30, pitch: 60, rhythm: 60, expression: 60, overall: 60)
        diagnosis_at(14, pitch: 70, rhythm: 60, expression: 60, overall: 65)
        diagnosis_at(1,  pitch: 75, rhythm: 65, expression: 68, overall: 70)
      end

      it "has_letter: true を返す" do
        expect(described_class.call(customer).has_letter).to be true
      end

      it "introduction に start_date が含まれること" do
        result = described_class.call(customer)
        expect(result.introduction).to be_present
      end

      it "journey に診断回数か週数が含まれること" do
        result = described_class.call(customer)
        expect(result.journey).to be_present
      end

      it "growth が成長タイプを含む文字列を返すこと" do
        result = described_class.call(customer)
        expect(result.growth).to be_present
      end
    end

    context "コーチ人格 gentle の場合" do
      let(:customer) { create(:customer, domain_name: "singing", singing_coach_personality: :gentle) }
      before { diagnosis_at(7) }

      it "personality が gentle になること" do
        expect(described_class.call(customer).personality).to eq "gentle"
      end

      it "coach_label が '優しい先生' であること" do
        expect(described_class.call(customer).coach_label).to eq "優しい先生"
      end
    end

    context "コーチ人格 artist の場合" do
      let(:customer) { create(:customer, domain_name: "singing", singing_coach_personality: :artist) }
      before { diagnosis_at(7) }

      it "personality が artist になること" do
        expect(described_class.call(customer).personality).to eq "artist"
      end

      it "coach_label が 'アーティスト' であること" do
        expect(described_class.call(customer).coach_label).to eq "アーティスト"
      end
    end

    context "streak が 3 日以上ある場合" do
      before do
        (1..5).each { |i| diagnosis_at(i) }
      end

      it "journey に streak の情報が含まれること" do
        result = described_class.call(customer)
        expect(result.journey).to be_present
      end
    end

    context "成長スコアがある場合" do
      before do
        diagnosis_at(30, pitch: 50, rhythm: 50, expression: 50, overall: 50)
        diagnosis_at(1,  pitch: 80, rhythm: 60, expression: 60, overall: 70)
      end

      it "growth が improvement テンプレートを使用すること" do
        result = described_class.call(customer)
        expect(result.growth).to be_present
      end
    end

    context "決定論的であること（同じ日は同じ結果）" do
      before { diagnosis_at(7) }

      it "同じ呼び出しで同じ結果を返す" do
        result1 = described_class.call(customer)
        result2 = described_class.call(customer)
        expect(result1.introduction).to  eq result2.introduction
        expect(result1.journey).to       eq result2.journey
        expect(result1.growth).to        eq result2.growth
        expect(result1.encouragement).to eq result2.encouragement
      end
    end
  end
end
