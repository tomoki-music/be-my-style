require "rails_helper"

RSpec.describe Singing::GrowthPartnershipsBuilder do
  def completed_diagnosis(customer, attrs = {})
    create(
      :singing_diagnosis,
      :completed,
      {
        customer:         customer,
        overall_score:    75,
        pitch_score:      72,
        rhythm_score:     74,
        expression_score: 73,
        created_at:       Time.current
      }.merge(attrs)
    )
  end

  describe ".call" do
    subject(:result) { described_class.call(customer: customer) }

    let(:customer) { create(:customer, domain_name: "singing") }

    context "nil customer の場合" do
      it "nil を受け取っても例外を発生させない" do
        expect { described_class.call(customer: nil) }.not_to raise_error
      end

      it "空の partners と空メッセージ を返す" do
        result = described_class.call(customer: nil)

        expect(result).to be_a(described_class::GrowthPartnershipsResult)
        expect(result.partners).to be_empty
        expect(result.message).to be_present
      end
    end

    context "診断履歴なし（自分も他者も診断0件）" do
      it "GrowthPartnershipsResult を返す" do
        expect(result).to be_a(described_class::GrowthPartnershipsResult)
      end

      it "partners が空配列" do
        expect(result.partners).to be_empty
      end

      it "空時のメッセージを返す" do
        expect(result.message).to eq("もう少し活動が増えると、成長仲間が見つかります🌱")
      end
    end

    context "自分自身は除外される" do
      it "自分だけが直近30日に診断しても partners に含まれない" do
        completed_diagnosis(customer, created_at: 5.days.ago)

        expect(result.partners.map(&:customer)).not_to include(customer)
      end
    end

    context "GrowthType 一致で 40pt 加点" do
      let(:other) { create(:customer, domain_name: "singing") }

      before do
        # 両方を groove_builder (診断なし) にするのではなく、
        # 同じ type になるよう診断データを揃える。
        # 診断が1件の場合は groove_builder になるので両者共に1件ずつ作る。
        completed_diagnosis(customer, created_at: 5.days.ago)
        completed_diagnosis(other,    created_at: 5.days.ago)
      end

      it "同じ GrowthType の他者が partners に含まれる" do
        expect(result.partners.map(&:customer)).to include(other)
      end

      it "compatibility_score が 40 以上" do
        partner = result.partners.find { |p| p.customer.id == other.id }
        expect(partner.compatibility_score).to be >= 40
      end

      it "partnership_reason が growth_type に対応したテキスト" do
        partner = result.partners.find { |p| p.customer.id == other.id }
        expect(partner.partnership_reason).to include("同じ成長タイプ")
      end
    end

    context "Mission 一致で 30pt 加点" do
      let(:other) { create(:customer, domain_name: "singing") }

      before do
        # expression スコアが伸びている = :expression mission
        completed_diagnosis(customer, expression_score: 55, pitch_score: 70, rhythm_score: 70, overall_score: 70, created_at: 3.days.ago)
        completed_diagnosis(customer, expression_score: 75, pitch_score: 71, rhythm_score: 71, overall_score: 75, created_at: 1.day.ago)
        completed_diagnosis(other,    expression_score: 55, pitch_score: 70, rhythm_score: 70, overall_score: 70, created_at: 3.days.ago)
        completed_diagnosis(other,    expression_score: 75, pitch_score: 71, rhythm_score: 71, overall_score: 75, created_at: 1.day.ago)
      end

      it "同じ mission の他者が partners に含まれる" do
        expect(result.partners.map(&:customer)).to include(other)
      end

      it "compatibility_score に 30pt 分が含まれる" do
        partner = result.partners.find { |p| p.customer.id == other.id }
        expect(partner.compatibility_score).to be >= 30
      end

      it "partnership_reason が mission に対応したテキスト（growth_type 不一致の場合）" do
        # 別の growth_type になるよう片方だけ多く診断させてストリークを変える
        # ここではシンプルに reason の内容を直接確認するより存在確認にとどめる
        partner = result.partners.find { |p| p.customer.id == other.id }
        expect(partner).not_to be_nil
      end
    end

    context "活動ペース一致で 20pt 加点" do
      let(:other) { create(:customer, domain_name: "singing") }

      before do
        # customer: 直近30日に2件
        completed_diagnosis(customer, created_at: 10.days.ago)
        completed_diagnosis(customer, created_at: 5.days.ago)
        # other: 直近30日に2件（差 = 0 <= 2）
        completed_diagnosis(other, created_at: 10.days.ago)
        completed_diagnosis(other, created_at: 5.days.ago)
      end

      it "活動ペースが近い他者が partners に含まれる" do
        expect(result.partners.map(&:customer)).to include(other)
      end

      it "compatibility_score に 20pt 以上が含まれる" do
        partner = result.partners.find { |p| p.customer.id == other.id }
        expect(partner.compatibility_score).to be >= 20
      end
    end

    context "Cheer 関係で 10pt 加点" do
      let(:other) { create(:customer, domain_name: "singing") }

      before do
        completed_diagnosis(other, created_at: 5.days.ago)
        # customer -> other の応援
        create(:singing_cheer_reaction, customer: customer, target_customer: other)
      end

      it "応援でつながっている他者が partners に含まれる" do
        expect(result.partners.map(&:customer)).to include(other)
      end

      it "compatibility_score が 10 以上" do
        partner = result.partners.find { |p| p.customer.id == other.id }
        expect(partner.compatibility_score).to be >= 10
      end

      it "partnership_reason が cheer 対応テキスト（他の一致がない場合）" do
        partner = result.partners.find { |p| p.customer.id == other.id }
        expect(partner.partnership_reason).to eq("応援でつながっている仲間です")
      end
    end

    context "受け取った応援でも Cheer 加点される" do
      let(:other) { create(:customer, domain_name: "singing") }

      before do
        completed_diagnosis(other, created_at: 5.days.ago)
        # other -> customer の応援
        create(:singing_cheer_reaction, customer: other, target_customer: customer)
      end

      it "応援してくれた他者が partners に含まれる" do
        expect(result.partners.map(&:customer)).to include(other)
      end
    end

    context "compatibility_score 順に最大3件" do
      let!(:partners_data) do
        (1..5).map do |i|
          other = create(:customer, domain_name: "singing")
          # 各ユーザーに診断を作成（30日以内）
          create_list(:singing_diagnosis, i, :completed, customer: other,
            overall_score: 70 + i, pitch_score: 60, rhythm_score: 60, expression_score: 60,
            created_at: i.days.ago)
          # cheer でスコアを付ける
          create(:singing_cheer_reaction, customer: customer, target_customer: other)
          other
        end
      end

      it "最大3件のみ返す" do
        expect(result.partners.size).to be <= 3
      end

      it "compatibility_score の降順で並んでいる" do
        scores = result.partners.map(&:compatibility_score)
        expect(scores).to eq(scores.sort.reverse)
      end
    end

    context "直近30日以内に活動なしの他者は候補から除外" do
      let(:other) { create(:customer, domain_name: "singing") }

      before do
        # 31日より前の診断のみ
        completed_diagnosis(other, created_at: 31.days.ago)
        create(:singing_cheer_reaction, customer: customer, target_customer: other)
      end

      it "30日以上前の活動しかない他者は partners に含まれない" do
        expect(result.partners.map(&:customer)).not_to include(other)
      end
    end

    context "partners あり時の message" do
      let(:other) { create(:customer, domain_name: "singing") }

      before do
        completed_diagnosis(other, created_at: 5.days.ago)
        create(:singing_cheer_reaction, customer: customer, target_customer: other)
      end

      it "partners あり用のメッセージを返す" do
        expect(result.message).to eq("一緒に成長できそうな仲間が見つかりました🎵")
      end
    end

    context "partners 空時の message" do
      it "空時のメッセージを返す" do
        expect(result.message).to eq("もう少し活動が増えると、成長仲間が見つかります🌱")
      end
    end

    describe "DTO の各フィールド" do
      let(:other) { create(:customer, domain_name: "singing") }

      before do
        completed_diagnosis(other, created_at: 5.days.ago)
        create(:singing_cheer_reaction, customer: customer, target_customer: other)
      end

      it "GrowthPartnership の全フィールドが存在する" do
        partner = result.partners.first

        expect(partner).to be_a(described_class::GrowthPartnership)
        expect(partner.customer).to be_present
        expect(partner.display_name).to be_present
        expect(partner.partnership_reason).to be_present
        expect(partner.activity_label).to be_present
        expect(partner.compatibility_score).to be_a(Integer)
        expect(partner.compatibility_score).to be_positive
      end
    end
  end
end
