require "rails_helper"

RSpec.describe Singing::AchievementRecapMovieBuilder, type: :service do
  let(:customer) { create(:customer, domain_name: "singing") }

  describe ".call" do
    subject(:result) { described_class.call(customer, year: 2026) }

    context "指定年にバッジがない場合（empty fallback）" do
      it "empty? が true であること" do
        expect(result.empty?).to be true
      end

      it "scenes が空であること" do
        expect(result.scenes).to be_empty
      end

      it "total_duration が 0 であること" do
        expect(result.total_duration).to eq(0)
      end

      it "year が正しく設定されること" do
        expect(result.year).to eq(2026)
      end
    end

    context "バッジが1件ある場合（最小構成）" do
      let!(:badge_jan) do
        create(:singing_achievement_badge, :first_diagnosis, customer: customer,
               earned_at: Time.zone.local(2026, 1, 10, 10, 0, 0))
      end

      it "empty? が false であること" do
        expect(result.empty?).to be false
      end

      it "scenes が空でないこと" do
        expect(result.scenes).not_to be_empty
      end

      it "先頭シーンが :hero であること" do
        expect(result.scenes.first.type).to eq(:hero)
      end

      it "末尾シーンが :ending であること" do
        expect(result.scenes.last.type).to eq(:ending)
      end

      it "total_duration が scenes の合計と一致すること" do
        expect(result.total_duration).to eq(result.scenes.sum(&:duration))
      end

      it "scenes の index が 0 始まりで連番であること" do
        indices = result.scenes.map(&:index)
        expect(indices).to eq((0...result.scenes.size).to_a)
      end
    end

    context "バッジが3件以上ある場合（growth scene 生成）" do
      let!(:badge1) do
        create(:singing_achievement_badge, :first_diagnosis, customer: customer,
               earned_at: Time.zone.local(2026, 1, 10, 10, 0, 0))
      end
      let!(:badge2) do
        create(:singing_achievement_badge, :streak_7, customer: customer,
               earned_at: Time.zone.local(2026, 3, 5, 10, 0, 0))
      end
      let!(:badge3) do
        create(:singing_achievement_badge, :diagnosis_10, customer: customer,
               earned_at: Time.zone.local(2026, 6, 20, 10, 0, 0))
      end

      it "scenes に :growth が含まれること" do
        types = result.scenes.map(&:type)
        expect(types).to include(:growth)
      end

      it ":first_achievement シーンが含まれること" do
        types = result.scenes.map(&:type)
        expect(types).to include(:first_achievement)
      end

      it "scenes が時系列（index 昇順）で並んでいること" do
        expect(result.scenes.map(&:index)).to eq(result.scenes.map(&:index).sort)
      end
    end

    context "legendary バッジが存在する場合" do
      before do
        allow_any_instance_of(Singing::YearlyAchievementRewindBuilder).to receive(:build).and_return(
          Singing::YearlyAchievementRewindBuilder::Result.new(
            year:                2026,
            total_count:         5,
            rarity_counts:       { legendary: 1, epic: 0, rare: 2, common: 2 },
            has_legendary:       true,
            has_epic:            false,
            representative_badge: nil,
            monthly_highlights:  [],
            first_earned:        nil,
            last_earned:         nil,
            milestone_count:     1,
            items:               [],
            empty:               false
          )
        )
      end

      it "scenes に :legendary が含まれること" do
        types = result.scenes.map(&:type)
        expect(types).to include(:legendary)
      end

      it "subtitle が 'Legendary 達成の年' であること" do
        expect(result.subtitle).to eq("Legendary 達成の年")
      end
    end

    context "monthly_peak scene の生成" do
      let!(:badge_jan1) do
        create(:singing_achievement_badge, :first_diagnosis, customer: customer,
               earned_at: Time.zone.local(2026, 1, 5, 10, 0, 0))
      end
      let!(:badge_jan2) do
        create(:singing_achievement_badge, :streak_7, customer: customer,
               earned_at: Time.zone.local(2026, 1, 15, 10, 0, 0))
      end
      let!(:badge_jan3) do
        create(:singing_achievement_badge, :diagnosis_10, customer: customer,
               earned_at: Time.zone.local(2026, 1, 25, 10, 0, 0))
      end
      let!(:badge_may) do
        create(:singing_achievement_badge, :growth_10, customer: customer,
               earned_at: Time.zone.local(2026, 5, 10, 10, 0, 0))
      end

      it "scenes に :monthly_peak が含まれること" do
        types = result.scenes.map(&:type)
        expect(types).to include(:monthly_peak)
      end

      it ":monthly_peak シーンのタイトルに月が含まれること" do
        peak_scene = result.scenes.find { |s| s.type == :monthly_peak }
        expect(peak_scene.title).to match(/月/)
      end
    end

    context "Scene 構造の検証" do
      let!(:badge) do
        create(:singing_achievement_badge, :first_diagnosis, customer: customer,
               earned_at: Time.zone.local(2026, 2, 1, 10, 0, 0))
      end

      it "各 scene に必須フィールドが存在すること" do
        result.scenes.each do |scene|
          expect(scene.type).to be_present
          expect(scene.title).to be_present
          expect(scene.subtitle).to be_present
          expect(scene.body).to be_present
          expect(scene.background_style).to be_present
          expect(scene.duration).to be_positive
          expect(scene.emotion).to be_present
          expect(scene.index).to be_a(Integer)
        end
      end

      it "background_style がすべて定義済みの値であること" do
        valid_styles = Singing::AchievementRecapMovieBuilder::BACKGROUND_STYLES
        result.scenes.each do |scene|
          expect(valid_styles).to include(scene.background_style)
        end
      end

      it "emotion がすべて定義済みの値であること" do
        valid_emotions = Singing::AchievementRecapMovieBuilder::EMOTIONS
        result.scenes.each do |scene|
          expect(valid_emotions).to include(scene.emotion)
        end
      end

      it "duration がすべて正の整数であること" do
        result.scenes.each do |scene|
          expect(scene.duration).to be_a(Integer)
          expect(scene.duration).to be > 0
        end
      end
    end

    context "total_duration の検証" do
      let!(:badge1) do
        create(:singing_achievement_badge, :first_diagnosis, customer: customer,
               earned_at: Time.zone.local(2026, 3, 1, 10, 0, 0))
      end
      let!(:badge2) do
        create(:singing_achievement_badge, :streak_7, customer: customer,
               earned_at: Time.zone.local(2026, 7, 1, 10, 0, 0))
      end
      let!(:badge3) do
        create(:singing_achievement_badge, :diagnosis_10, customer: customer,
               earned_at: Time.zone.local(2026, 9, 1, 10, 0, 0))
      end

      it "total_duration が scenes の duration 合計と一致すること" do
        expect(result.total_duration).to eq(result.scenes.sum(&:duration))
      end

      it "total_duration が正の値であること" do
        expect(result.total_duration).to be > 0
      end
    end
  end
end
