require "rails_helper"

RSpec.describe Singing::ProfileConnectionBuilder do
  describe ".call" do
    subject(:connection) { described_class.call(customer) }

    let(:customer) { create(:customer, domain_name: "singing") }

    it "nil customer で nil を返す" do
      expect(described_class.call(nil)).to be_nil
    end

    it "ProfileConnection DTO を返す" do
      expect(connection).to be_a(described_class::ProfileConnection)
    end

    describe "circle_name" do
      it "成長サークル名が返る" do
        expect(connection.circle_name).to be_a(String)
        expect(connection.circle_name).to be_present
      end

      it "デフォルトは Groove Builder Circle" do
        expect(connection.circle_name).to include("Groove Builder Circle")
      end
    end

    describe "circle_slug" do
      it "circle_slug が返る" do
        expect(connection.circle_slug).to be_present
      end

      it "デフォルトは groove_builder" do
        expect(connection.circle_slug).to eq("groove_builder")
      end

      context "Emotional Singer タイプの診断がある場合" do
        it "emotional_singer が返る" do
          older  = create(:singing_diagnosis, :completed, customer: customer,
                          expression_score: 50, pitch_score: 50, rhythm_score: 50,
                          overall_score: 60)
          create(:singing_diagnosis, :completed, customer: customer,
                 expression_score: 65, pitch_score: 52, rhythm_score: 51,
                 overall_score: 65,
                 created_at: older.created_at + 1.day,
                 diagnosed_at: older.diagnosed_at + 1.day)

          expect(connection.circle_slug).to eq("emotional_singer")
        end
      end
    end

    describe "connection_count" do
      it "データなしで 0 を返す" do
        expect(connection.connection_count).to eq(0)
      end

      it "応援でつながると connection_count が増える" do
        target = create(:customer, domain_name: "singing")
        create(:singing_cheer_reaction, customer: customer, target_customer: target)

        expect(connection.connection_count).to be >= 1
      end
    end

    describe "show_follow_cta" do
      it "常に true を返す" do
        expect(connection.show_follow_cta).to eq(true)
      end
    end

    describe "show_circle_cta" do
      it "circle_slug がある場合は true" do
        expect(connection.show_circle_cta).to eq(true)
      end
    end

    describe "cta_message（状態に応じて変わる）" do
      context "つながりがない（0人）" do
        it "「一緒に挑戦する仲間を見つけよう」を返す" do
          expect(connection.cta_message).to eq("一緒に挑戦する仲間を見つけよう")
        end
      end

      context "応援でつながりが1件以上ある" do
        it "「同じ音楽を楽しむ仲間がいます」を返す" do
          target = create(:customer, domain_name: "singing")
          create(:singing_cheer_reaction, customer: customer, target_customer: target)

          expect(connection.cta_message).to eq("同じ音楽を楽しむ仲間がいます")
        end
      end

      context "つながりが10件以上" do
        it "「応援し合える仲間が増えています」を返す" do
          10.times do
            target = create(:customer, domain_name: "singing")
            create(:singing_cheer_reaction, customer: customer, target_customer: target)
          end

          expect(connection.cta_message).to eq("応援し合える仲間が増えています")
        end
      end
    end
  end
end
