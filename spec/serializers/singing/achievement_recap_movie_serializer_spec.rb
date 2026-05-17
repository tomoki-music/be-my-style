require "rails_helper"

RSpec.describe Singing::AchievementRecapMovieSerializer, type: :serializer do
  let(:customer) { create(:customer, domain_name: "singing") }

  def build_result(year: 2026)
    Singing::AchievementRecapMovieBuilder.call(customer, year: year)
  end

  describe "#as_json" do
    context "empty result（バッジなし）" do
      subject(:json) { described_class.new(build_result).as_json }

      it "必須トップレベルキーが揃っていること" do
        expect(json.keys).to contain_exactly(:year, :title, :subtitle, :total_duration, :empty, :scenes)
      end

      it "empty: true であること" do
        expect(json[:empty]).to be true
      end

      it "scenes が空配列であること" do
        expect(json[:scenes]).to eq([])
      end

      it "total_duration が 0 であること" do
        expect(json[:total_duration]).to eq(0)
      end

      it "year が整数であること" do
        expect(json[:year]).to eq(2026)
      end

      it "ActiveRecord オブジェクトを含まないこと" do
        json.to_s.tap do |str|
          expect(str).not_to include("ActiveRecord")
        end
      end
    end

    context "バッジありの result" do
      before do
        create(:singing_achievement_badge, :first_diagnosis, customer: customer,
               earned_at: Time.zone.local(2026, 1, 10, 10, 0, 0))
        create(:singing_achievement_badge, :streak_7, customer: customer,
               earned_at: Time.zone.local(2026, 3, 5, 10, 0, 0))
        create(:singing_achievement_badge, :diagnosis_10, customer: customer,
               earned_at: Time.zone.local(2026, 6, 20, 10, 0, 0))
      end

      subject(:json) { described_class.new(build_result).as_json }

      it "empty: false であること" do
        expect(json[:empty]).to be false
      end

      it "scenes が配列であること" do
        expect(json[:scenes]).to be_an(Array)
        expect(json[:scenes]).not_to be_empty
      end

      it "total_duration が正の整数であること" do
        expect(json[:total_duration]).to be > 0
      end

      describe "scene 構造" do
        let(:scene) { json[:scenes].first }

        it "必須キーが揃っていること" do
          expect(scene.keys).to contain_exactly(
            :index, :type, :title, :subtitle, :body,
            :duration, :emotion, :background_style, :badge
          )
        end

        it "type が文字列であること" do
          json[:scenes].each do |s|
            expect(s[:type]).to be_a(String)
          end
        end

        it "emotion が文字列であること" do
          json[:scenes].each do |s|
            expect(s[:emotion]).to be_a(String)
          end
        end

        it "background_style が文字列であること" do
          json[:scenes].each do |s|
            expect(s[:background_style]).to be_a(String)
          end
        end

        it "index が 0 始まりの連番であること" do
          indices = json[:scenes].map { |s| s[:index] }
          expect(indices).to eq((0...json[:scenes].size).to_a)
        end

        it "duration が正の整数であること" do
          json[:scenes].each do |s|
            expect(s[:duration]).to be_a(Integer)
            expect(s[:duration]).to be > 0
          end
        end

        it "先頭シーンが hero であること" do
          expect(json[:scenes].first[:type]).to eq("hero")
        end

        it "末尾シーンが ending であること" do
          expect(json[:scenes].last[:type]).to eq("ending")
        end
      end

      describe "badge シリアライズ" do
        it "badge を持つ scene は必要最小限のキーだけを返すこと" do
          badge_scene = json[:scenes].find { |s| s[:badge].present? }
          next unless badge_scene

          expect(badge_scene[:badge].keys).to contain_exactly(
            :label, :emoji, :rarity, :earned_at, :description
          )
        end

        it "badge の rarity が文字列であること" do
          badge_scenes = json[:scenes].select { |s| s[:badge].present? }
          badge_scenes.each do |s|
            expect(s[:badge][:rarity]).to be_a(String)
          end
        end

        it "badge の earned_at が YYYY-MM-DD 形式であること" do
          badge_scenes = json[:scenes].select { |s| s[:badge].present? }
          badge_scenes.each do |s|
            expect(s[:badge][:earned_at]).to match(/\A\d{4}-\d{2}-\d{2}\z/)
          end
        end

        it "badge が nil のシーンは null を返すこと" do
          growth_scene = json[:scenes].find { |s| s[:type] == "growth" }
          expect(growth_scene[:badge]).to be_nil if growth_scene
        end
      end

      it "ActiveRecord オブジェクトをシリアライズ結果に含めないこと" do
        json_str = json.to_json
        expect(json_str).not_to include("ActiveRecord")
        expect(json_str).not_to include("SingingAchievementBadge")
      end
    end
  end
end
