require 'rails_helper'

RSpec.describe Singing::GrowthTimelineService do
  let(:customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let(:other_customer) { FactoryBot.create(:customer, domain_name: "singing") }

  describe ".call" do
    it "診断・スコア成長・AIチャレンジ・バッジを新しい順で最大10件返すこと" do
      now = Time.zone.local(2026, 7, 10, 12, 0, 0)
      FactoryBot.create(
        :singing_diagnosis,
        :completed,
        customer: customer,
        created_at: now - 2.months,
        diagnosed_at: now - 2.months,
        overall_score: 70,
        rhythm_score: 62,
        pitch_score: 70,
        expression_score: 70
      )
      FactoryBot.create(
        :singing_diagnosis,
        :completed,
        customer: customer,
        created_at: now - 1.month,
        diagnosed_at: now - 1.month,
        overall_score: 78,
        rhythm_score: 70,
        pitch_score: 69,
        expression_score: 72
      )
      FactoryBot.create(
        :singing_ai_challenge_progress,
        customer: customer,
        target_key: "rhythm",
        challenge_month: (now - 1.month).to_date.beginning_of_month,
        tried: true,
        completed: true,
        completed_at: now - 20.days,
        created_at: now - 45.days,
        updated_at: now - 20.days
      )
      FactoryBot.create_list(
        :singing_diagnosis,
        9,
        :completed,
        customer: customer,
        created_at: now - 4.months,
        diagnosed_at: now - 4.months,
        overall_score: 60
      )

      events = described_class.call(customer)

      expect(events.size).to eq 10
      expect(events.map(&:occurred_at)).to eq(events.map(&:occurred_at).sort.reverse)
      expect(events.map(&:title)).to include(
        "総合スコア +8点成長",
        "リズムスコア +8点成長",
        "リズムチャレンジ完了",
        "リズムチャレンジ達成バッジ獲得"
      )
    end

    it "current_customer以外の診断とprogressを参照しないこと" do
      FactoryBot.create(
        :singing_diagnosis,
        :completed,
        customer: other_customer,
        song_title: "Other Singing",
        overall_score: 99,
        rhythm_score: 99
      )
      FactoryBot.create(
        :singing_ai_challenge_progress,
        customer: other_customer,
        target_key: "rhythm",
        tried: true,
        completed: true
      )

      events = described_class.call(customer)

      expect(events).to be_empty
    end

    context "Recap Movie イベント" do
      it "シェア済み Recap Movie のシェアイベントを返すこと" do
        FactoryBot.create(
          :singing_generated_recap_movie,
          customer: customer,
          year: 2024,
          status: :completed,
          first_shared_at: 1.month.ago
        )

        events = described_class.call(customer)

        expect(events.map(&:title)).to include("🎬 Recap Movieをシェアしました")
      end

      it "ダウンロード済み Recap Movie のダウンロードイベントを返すこと" do
        FactoryBot.create(
          :singing_generated_recap_movie,
          customer: customer,
          year: 2024,
          status: :completed,
          last_downloaded_at: 1.month.ago
        )

        events = described_class.call(customer)

        expect(events.map(&:title)).to include("📥 Recap Movieをダウンロードしました")
      end

      it "Instagram導線クリック済みの Recap Movie のイベントを返すこと" do
        FactoryBot.create(
          :singing_generated_recap_movie,
          customer: customer,
          year: 2024,
          status: :completed,
          last_instagram_hint_clicked_at: 1.month.ago
        )

        events = described_class.call(customer)

        expect(events.map(&:title)).to include("📱 Instagram投稿に挑戦しました")
      end

      it "活動のない Recap Movie はイベントを生成しないこと" do
        FactoryBot.create(
          :singing_generated_recap_movie,
          customer: customer,
          year: 2024,
          status: :completed,
          first_shared_at: nil,
          last_downloaded_at: nil,
          last_instagram_hint_clicked_at: nil
        )

        events = described_class.call(customer)

        recap_events = events.select { |e| e.key.start_with?("recap_movie_") }
        expect(recap_events).to be_empty
      end

      it "他ユーザーの Recap Movie イベントを含まないこと" do
        FactoryBot.create(
          :singing_generated_recap_movie,
          customer: other_customer,
          year: 2024,
          status: :completed,
          first_shared_at: 1.month.ago
        )

        events = described_class.call(customer)

        recap_events = events.select { |e| e.key.start_with?("recap_movie_") }
        expect(recap_events).to be_empty
      end
    end

    it "nilスコアや前回データ不足があっても落ちずに診断完了イベントを返すこと" do
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        overall_score: nil,
        pitch_score: nil,
        rhythm_score: nil,
        expression_score: nil
      )

      events = described_class.call(customer)

      expect(events.map(&:title)).to include("#{diagnosis.performance_type_label}診断完了")
    end
  end
end
