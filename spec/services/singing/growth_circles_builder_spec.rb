require "rails_helper"

RSpec.describe Singing::GrowthCirclesBuilder do
  def completed_diagnosis(customer, attrs = {})
    create(
      :singing_diagnosis,
      :completed,
      {
        customer: customer,
        overall_score: 75,
        pitch_score: 72,
        rhythm_score: 74,
        expression_score: 73,
        created_at: Time.current
      }.merge(attrs)
    )
  end

  describe ".call" do
    context "customer が nil の場合" do
      it "空配列を返す" do
        circles = described_class.call(nil)

        expect(circles).to eq([])
      end
    end

    context "診断なしの customer" do
      it "DTO の配列を返す" do
        customer = create(:customer, domain_name: "singing")

        circles = described_class.call(customer)

        expect(circles).to be_an(Array)
      end

      it "各要素が GrowthCircle DTO である" do
        customer = create(:customer, domain_name: "singing")

        circles = described_class.call(customer)

        circles.each do |circle|
          expect(circle).to be_a(described_class::GrowthCircle)
        end
      end
    end

    context "GrowthType 系 circle 生成" do
      it "emotional_singer タイプで Emotional Singer Circle が含まれる" do
        customer = create(:customer, domain_name: "singing")
        completed_diagnosis(
          customer,
          overall_score: 70, pitch_score: 60, rhythm_score: 60, expression_score: 60,
          created_at: 2.days.ago
        )
        completed_diagnosis(
          customer,
          overall_score: 78, pitch_score: 61, rhythm_score: 60, expression_score: 80,
          created_at: 1.day.ago
        )

        circles = described_class.call(customer)

        growth_circle = circles.find { |c| c.circle_type.to_s.start_with?("growth_type_") }
        expect(growth_circle).not_to be_nil
        expect(growth_circle.title).to include("Emotional Singer Circle")
      end

      it "member_count が正の整数である" do
        customer = create(:customer, domain_name: "singing")
        completed_diagnosis(customer)

        circles = described_class.call(customer)

        circles.each do |circle|
          expect(circle.member_count).to be_a(Integer)
          expect(circle.member_count).to be_positive
        end
      end
    end

    context "Mission 系 circle 生成" do
      it "expression スコアが伸びた場合 Expression Challenge Circle が含まれる" do
        customer = create(:customer, domain_name: "singing")
        completed_diagnosis(
          customer,
          overall_score: 70, pitch_score: 60, rhythm_score: 60, expression_score: 55,
          created_at: 3.days.ago
        )
        completed_diagnosis(
          customer,
          overall_score: 75, pitch_score: 61, rhythm_score: 60, expression_score: 78,
          created_at: 1.day.ago
        )

        circles = described_class.call(customer)

        mission_circle = circles.find { |c| c.circle_type.to_s.start_with?("mission_") }
        expect(mission_circle).not_to be_nil
        expect(mission_circle.title).to include("Expression Challenge Circle")
      end

      it "rhythm スコアが最も伸びた場合 Rhythm Practice Circle が含まれる" do
        customer = create(:customer, domain_name: "singing")
        completed_diagnosis(
          customer,
          overall_score: 70, pitch_score: 60, rhythm_score: 55, expression_score: 60,
          created_at: 3.days.ago
        )
        completed_diagnosis(
          customer,
          overall_score: 76, pitch_score: 61, rhythm_score: 79, expression_score: 61,
          created_at: 1.day.ago
        )

        circles = described_class.call(customer)

        mission_circle = circles.find { |c| c.circle_type == :mission_rhythm }
        expect(mission_circle).not_to be_nil
        expect(mission_circle.title).to include("Rhythm Practice Circle")
      end
    end

    context "Cheer 系 circle 生成" do
      it "30日以内に3回以上応援した場合 Cheer Circle が含まれる" do
        customer    = create(:customer, domain_name: "singing")
        target_customers = 3.times.map { create(:customer, domain_name: "singing") }
        target_customers.each do |target|
          create(
            :singing_cheer_reaction,
            customer: customer,
            target_customer: target,
            created_at: 10.days.ago
          )
        end

        circles = described_class.call(customer)

        cheer_circle = circles.find { |c| c.circle_type == :cheer }
        expect(cheer_circle).not_to be_nil
        expect(cheer_circle.title).to include("Cheer Circle")
      end

      it "応援が閾値未満の場合 Cheer Circle は含まれない" do
        customer = create(:customer, domain_name: "singing")
        target = create(:customer, domain_name: "singing")
        create(
          :singing_cheer_reaction,
          customer: customer,
          target_customer: target,
          created_at: 10.days.ago
        )

        circles = described_class.call(customer)

        cheer_circle = circles.find { |c| c.circle_type == :cheer }
        expect(cheer_circle).to be_nil
      end
    end

    context "DTO の各フィールド" do
      it "title, description, member_count, message, circle_type がすべて存在する" do
        customer = create(:customer, domain_name: "singing")
        completed_diagnosis(customer)

        circles = described_class.call(customer)

        circles.each do |circle|
          expect(circle.title).to be_present
          expect(circle.description).to be_present
          expect(circle.member_count).to be_present
          expect(circle.message).to be_present
          expect(circle.circle_type).to be_present
        end
      end
    end

    context "空状態対応" do
      it "診断なし・応援なしでも例外を発生させない" do
        customer = create(:customer, domain_name: "singing")

        expect { described_class.call(customer) }.not_to raise_error
      end

      it "nil customer でも例外を発生させない" do
        expect { described_class.call(nil) }.not_to raise_error
      end
    end
  end
end
