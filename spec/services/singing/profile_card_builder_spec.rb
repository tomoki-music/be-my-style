require "rails_helper"

RSpec.describe Singing::ProfileCardBuilder do
  let(:customer) { create(:customer, domain_name: "singing", name: "テストユーザー") }

  describe ".call" do
    context "nil customer の場合" do
      it "nil を返す" do
        expect(described_class.call(nil)).to be_nil
      end
    end

    context "診断がない場合" do
      it "ProfileCard を返す" do
        expect(described_class.call(customer)).to be_a(described_class::ProfileCard)
      end

      it "display_name が返る" do
        card = described_class.call(customer)
        expect(card.display_name).to eq("テストユーザー")
      end

      it "growth_type_label が返る" do
        card = described_class.call(customer)
        expect(card.growth_type_label).to be_a(String)
        expect(card.growth_type_label).to be_present
      end

      it "growth_type_icon が返る" do
        card = described_class.call(customer)
        expect(card.growth_type_icon).to be_a(String)
        expect(card.growth_type_icon).to be_present
      end

      it "latest_activity_label が返る" do
        card = described_class.call(customer)
        expect(card.latest_activity_label).to be_a(String)
        expect(card.latest_activity_label).to be_present
      end

      it "avatar_attached が false である" do
        card = described_class.call(customer)
        expect(card.avatar_attached).to eq(false)
      end

      it "customer を保持する" do
        card = described_class.call(customer)
        expect(card.customer).to eq(customer)
      end
    end

    context "1件の診断がある場合" do
      before do
        create(:singing_diagnosis, :completed, customer: customer,
               overall_score: 75, pitch_score: 72, rhythm_score: 76, expression_score: 73)
      end

      it "ProfileCard を返す" do
        expect(described_class.call(customer)).to be_a(described_class::ProfileCard)
      end

      it "growth_type_label が空でない" do
        card = described_class.call(customer)
        expect(card.growth_type_label).to be_present
      end

      it "latest_activity_label が空でない" do
        card = described_class.call(customer)
        expect(card.latest_activity_label).to be_present
      end
    end

    context "consistency_hero 判定になる場合（連続7日以上）" do
      before do
        7.times do |i|
          create(:singing_diagnosis, :completed, customer: customer,
                 overall_score: 70, pitch_score: 68, rhythm_score: 70, expression_score: 69,
                 created_at: i.days.ago)
        end
      end

      it "latest_activity_label が継続系になる" do
        card = described_class.call(customer)
        expect(card.latest_activity_label).to eq("コツコツ診断を重ねています")
      end

      it "growth_type_label が Consistency Hero になる" do
        card = described_class.call(customer)
        expect(card.growth_type_label).to eq("Consistency Hero")
      end
    end

    context "diagnoses を事前渡しした場合" do
      let(:diagnoses) do
        [
          build_stubbed(:singing_diagnosis, :completed,
                        customer: customer, overall_score: 65,
                        pitch_score: 60, rhythm_score: 70, expression_score: 60,
                        created_at: 1.day.ago)
        ]
      end

      it "DB を叩かずに ProfileCard を返す" do
        card = described_class.call(customer, diagnoses: diagnoses)
        expect(card).to be_a(described_class::ProfileCard)
        expect(card.growth_type_label).to be_present
      end
    end
  end

  describe ".build_collection" do
    context "空配列を渡した場合" do
      it "空配列を返す" do
        expect(described_class.build_collection([])).to eq([])
      end
    end

    context "nil を渡した場合" do
      it "空配列を返す" do
        expect(described_class.build_collection(nil)).to eq([])
      end
    end

    context "複数ユーザーを渡した場合" do
      let(:other) { create(:customer, domain_name: "singing", name: "別ユーザー") }

      before do
        create(:singing_diagnosis, :completed, customer: customer,
               overall_score: 75, pitch_score: 72, rhythm_score: 76, expression_score: 73)
        create(:singing_diagnosis, :completed, customer: other,
               overall_score: 68, pitch_score: 65, rhythm_score: 70, expression_score: 64)
      end

      it "配列で返る" do
        result = described_class.build_collection([customer, other])
        expect(result).to be_an(Array)
      end

      it "ユーザー数分の ProfileCard を返す" do
        result = described_class.build_collection([customer, other])
        expect(result.size).to eq(2)
      end

      it "各要素が ProfileCard である" do
        result = described_class.build_collection([customer, other])
        result.each do |card|
          expect(card).to be_a(described_class::ProfileCard)
        end
      end

      it "各カードが display_name を持つ" do
        result = described_class.build_collection([customer, other])
        names = result.map(&:display_name)
        expect(names).to include("テストユーザー", "別ユーザー")
      end

      it "各カードが growth_type_label を持つ" do
        result = described_class.build_collection([customer, other])
        result.each do |card|
          expect(card.growth_type_label).to be_present
        end
      end

      it "各カードが latest_activity_label を持つ" do
        result = described_class.build_collection([customer, other])
        result.each do |card|
          expect(card.latest_activity_label).to be_present
        end
      end
    end

    context "診断のないユーザーが混在する場合" do
      let(:no_diagnosis_user) { create(:customer, domain_name: "singing", name: "診断なし") }

      before do
        create(:singing_diagnosis, :completed, customer: customer,
               overall_score: 75, pitch_score: 72, rhythm_score: 76, expression_score: 73)
      end

      it "診断なしユーザーも ProfileCard を返す" do
        result = described_class.build_collection([customer, no_diagnosis_user])
        expect(result.size).to eq(2)
      end

      it "診断なしユーザーの latest_activity_label も返る" do
        result = described_class.build_collection([customer, no_diagnosis_user])
        no_diagnosis_card = result.find { |c| c.customer == no_diagnosis_user }
        expect(no_diagnosis_card.latest_activity_label).to be_present
      end
    end
  end

  describe "ProfileCard DTO" do
    subject(:card) { described_class.call(customer) }

    it "customer を持つ" do
      expect(card.customer).to eq(customer)
    end

    it "display_name が String である" do
      expect(card.display_name).to be_a(String)
    end

    it "avatar_attached が Boolean である" do
      expect([true, false]).to include(card.avatar_attached)
    end

    it "growth_type_label が String である" do
      expect(card.growth_type_label).to be_a(String)
    end

    it "growth_type_icon が String である" do
      expect(card.growth_type_icon).to be_a(String)
    end

    it "latest_activity_label が String である" do
      expect(card.latest_activity_label).to be_a(String)
    end
  end
end
