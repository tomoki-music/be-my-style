require "rails_helper"

RSpec.describe Singing::YearlyGrowthReport, type: :service do
  let(:customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let(:other_customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let(:reference_time) { Time.zone.parse("2026-12-20 12:00:00") }

  describe ".call" do
    it "current customerの今年の診断とAIチャレンジだけで年間成長を集計すること" do
      FactoryBot.create(
        :singing_diagnosis,
        :completed,
        customer: customer,
        song_title: "Blue Voice",
        created_at: Time.zone.parse("2026-01-10 10:00:00"),
        overall_score: 60,
        pitch_score: 50,
        rhythm_score: 61,
        expression_score: 55
      )
      FactoryBot.create(
        :singing_diagnosis,
        :completed,
        customer: customer,
        song_title: "Blue Voice",
        created_at: Time.zone.parse("2026-06-10 10:00:00"),
        overall_score: 68,
        pitch_score: 66,
        rhythm_score: 64,
        expression_score: 63
      )
      FactoryBot.create(
        :singing_diagnosis,
        :completed,
        customer: customer,
        song_title: "Night Run",
        created_at: Time.zone.parse("2026-11-10 10:00:00"),
        overall_score: 72,
        pitch_score: 82,
        rhythm_score: 70,
        expression_score: 65
      )
      FactoryBot.create(
        :singing_diagnosis,
        :completed,
        customer: customer,
        song_title: "Last Year",
        created_at: Time.zone.parse("2025-12-10 10:00:00"),
        overall_score: 99,
        pitch_score: 99
      )
      FactoryBot.create(
        :singing_diagnosis,
        :completed,
        customer: other_customer,
        song_title: "Other Song",
        created_at: Time.zone.parse("2026-07-10 10:00:00"),
        overall_score: 100,
        pitch_score: 100
      )
      FactoryBot.create(
        :singing_ai_challenge_progress,
        customer: customer,
        target_key: "pitch",
        challenge_month: Date.new(2026, 2, 1),
        tried: true
      )
      FactoryBot.create(
        :singing_ai_challenge_progress,
        customer: customer,
        target_key: "pitch",
        challenge_month: Date.new(2026, 3, 1),
        completed: true
      )
      FactoryBot.create(
        :singing_ai_challenge_progress,
        customer: customer,
        target_key: "rhythm",
        challenge_month: Date.new(2026, 4, 1),
        tried: true
      )
      FactoryBot.create(
        :singing_ai_challenge_progress,
        customer: other_customer,
        target_key: "expression",
        challenge_month: Date.new(2026, 5, 1),
        tried: true
      )

      report = described_class.call(customer, reference_time: reference_time)

      expect(report.year).to eq(2026)
      expect(report.diagnosis_count).to eq(3)
      expect(report.top_growth.label).to eq("音程")
      expect(report.top_growth.delta).to eq(32)
      expect(report.personal_best_updates_count).to eq(3)
      expect(report.top_challenge.label).to eq("音程")
      expect(report.top_challenge.count).to eq(2)
      expect(report.top_song.title).to eq("Blue Voice")
      expect(report.top_song.count).to eq(2)
      expect(report.coach_message).to include("音程")
      expect(report.emotional_copy).to include("2026年")
    end

    it "診断がない場合は空のレポートとして扱うこと" do
      report = described_class.call(customer, reference_time: reference_time)

      expect(report).not_to be_present
      expect(report.diagnosis_count).to eq(0)
      expect(report.top_growth).to be_nil
      expect(report.top_song).to be_nil
    end
  end
end

RSpec.describe Singing::YearlyGrowthShareImageBuilder, type: :service do
  let(:customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let(:reference_time) { Time.zone.parse("2026-12-20 12:00:00") }

  describe ".call" do
    it "年間成長レポートをSNSシェア用の表示値に変換すること" do
      customer.create_subscription!(status: "active", plan: "core")
      FactoryBot.create(
        :singing_diagnosis,
        :completed,
        customer: customer,
        song_title: "Share Song",
        created_at: Time.zone.parse("2026-01-10 10:00:00"),
        overall_score: 60,
        pitch_score: 50,
        rhythm_score: 61,
        expression_score: 55
      )
      FactoryBot.create(
        :singing_diagnosis,
        :completed,
        customer: customer,
        song_title: "Share Song",
        created_at: Time.zone.parse("2026-11-10 10:00:00"),
        overall_score: 76,
        pitch_score: 82,
        rhythm_score: 70,
        expression_score: 65
      )
      FactoryBot.create(
        :singing_ai_challenge_progress,
        customer: customer,
        target_key: "pitch",
        challenge_month: Date.new(2026, 8, 1),
        tried: true
      )

      share_image = described_class.call(customer, reference_time: reference_time)

      expect(share_image).to be_present
      expect(share_image.headline).to eq("音程が今年いちばん伸びた")
      expect(share_image.growth_delta_label).to eq("+32点")
      expect(share_image.growth_range_label).to eq("50点から82点")
      expect(share_image.best_updates_label).to eq("2回")
      expect(share_image.challenge_label).to eq("音程 1回")
      expect(share_image.song_label).to eq("Share Song 2回")
      expect(share_image.hashtag).to eq("#BeMyStyleSinging")
      expect(share_image.x_share_text).to include("2026年は診断2回")
      expect(share_image.x_share_text).to include("音程が32点成長")
    end
  end
end
