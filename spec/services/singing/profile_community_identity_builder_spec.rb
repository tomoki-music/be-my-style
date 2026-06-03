require "rails_helper"

RSpec.describe Singing::ProfileCommunityIdentityBuilder do
  describe ".call" do
    subject(:identity) { described_class.call(customer) }

    let(:customer) { create(:customer, domain_name: "singing") }

    it "nil customer で nil を返す" do
      expect(described_class.call(nil)).to be_nil
    end

    it "ProfileCommunityIdentity DTO を返す" do
      expect(identity).to be_a(described_class::ProfileCommunityIdentity)
    end

    context "診断なし" do
      it "nil にならず DTO を返す" do
        expect(identity).not_to be_nil
      end

      it "reputation_points が 0 を返す" do
        expect(identity.reputation_points).to eq(0)
      end

      it "growth_type_label が返る（Groove Builder デフォルト）" do
        expect(identity.growth_type_label).to eq("Groove Builder")
      end

      it "growth_circle_name が返る" do
        expect(identity.growth_circle_name).to be_present
      end

      it "mission_label が返る" do
        expect(identity.mission_label).to be_present
      end

      it "activity_summary がデフォルトメッセージを返す" do
        expect(identity.activity_summary).to eq("音楽の輪に参加しています")
      end

      it "identity_message がデフォルトメッセージを返す" do
        expect(identity.identity_message).to eq("自分のペースで歌を楽しむメンバーです。")
      end
    end

    describe "reputation_title" do
      it "Seed レベルの称号を返す（データなし）" do
        expect(identity.reputation_title).to eq("🌱 Seed")
      end

      it "診断が増えるとレベルが上がる" do
        create_list(:singing_diagnosis, 50, :completed, customer: customer)

        expect(identity.reputation_title).to eq("🤝 Supporter")
      end
    end

    describe "reputation_points" do
      it "データなしで 0 を返す" do
        expect(identity.reputation_points).to eq(0)
      end

      it "診断回数に応じてポイントが増える" do
        create_list(:singing_diagnosis, 3, :completed, customer: customer)

        expect(identity.reputation_points).to eq(3)
      end

      it "応援もポイントに反映される" do
        target = create(:customer, domain_name: "singing")
        create(:singing_cheer_reaction, customer: customer, target_customer: target)

        expect(identity.reputation_points).to eq(2)
      end
    end

    describe "growth_type_label" do
      it "診断なしで Groove Builder を返す" do
        expect(identity.growth_type_label).to eq("Groove Builder")
      end

      it "2件の診断がある場合も growth_type_label が返る" do
        create_list(:singing_diagnosis, 2, :completed, customer: customer)

        expect(identity.growth_type_label).to be_present
      end
    end

    describe "growth_circle_name" do
      it "成長サークル名が返る" do
        expect(identity.growth_circle_name).to be_a(String)
      end

      it "Groove Builder サークルが含まれる（デフォルト）" do
        expect(identity.growth_circle_name).to include("Groove Builder Circle")
      end
    end

    describe "mission_label" do
      context "次のミッションタイトルが設定されている場合" do
        it "診断の next_mission_title を返す" do
          create(:singing_diagnosis, :completed, customer: customer, next_mission_title: "表現力を伸ばす")

          expect(identity.mission_label).to eq("表現力を伸ばす")
        end
      end

      context "next_mission_title がない場合" do
        it "growth_type に対応するデフォルトラベルを返す" do
          expect(identity.mission_label).to be_present
        end
      end
    end

    describe "activity_summary（状態に応じて変わる）" do
      context "データなし" do
        it "「音楽の輪に参加しています」を返す" do
          expect(identity.activity_summary).to eq("音楽の輪に参加しています")
        end
      end

      context "応援リアクションがある" do
        it "「仲間への応援が広がっています」を返す" do
          target = create(:customer, domain_name: "singing")
          create(:singing_cheer_reaction, customer: customer, target_customer: target)

          expect(identity.activity_summary).to eq("仲間への応援が広がっています")
        end
      end

      context "Performer レベル以上（150回以上の診断）" do
        it "「挑戦を重ねながら成長しています」を返す" do
          create_list(:singing_diagnosis, 150, :completed, customer: customer)

          expect(identity.activity_summary).to eq("挑戦を重ねながら成長しています")
        end
      end

      context "診断 3 回以上（応援なし、Performer 未満）" do
        it "「コツコツ歌を楽しんでいます」を返す" do
          create_list(:singing_diagnosis, 3, :completed, customer: customer)

          expect(identity.activity_summary).to eq("コツコツ歌を楽しんでいます")
        end
      end
    end

    describe "identity_message（状態に応じて変わる）" do
      context "データなし" do
        it "デフォルトメッセージを返す" do
          expect(identity.identity_message).to eq("自分のペースで歌を楽しむメンバーです。")
        end
      end

      context "応援リアクションがある" do
        it "応援メッセージを返す" do
          target = create(:customer, domain_name: "singing")
          create(:singing_cheer_reaction, customer: customer, target_customer: target)

          expect(identity.identity_message).to eq("仲間を応援しながら、音楽の輪を広げています。")
        end
      end
    end
  end
end
