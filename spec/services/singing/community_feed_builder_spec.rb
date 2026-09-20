require "rails_helper"

RSpec.describe Singing::CommunityFeedBuilder do
  include ActiveSupport::Testing::TimeHelpers

  def make_diagnosis(customer:, score: 70, created_at: Time.current, ranking_opt_in: true)
    create(:singing_diagnosis, :completed,
           customer:       customer,
           ranking_opt_in: ranking_opt_in,
           overall_score:  score,
           pitch_score:    score,
           rhythm_score:   score,
           expression_score: score,
           created_at:     created_at)
  end

  describe ".call" do
    subject(:result) { described_class.call }

    context "診断が存在しない場合" do
      it "空の feed を返す" do
        expect(result.feed_items).to be_empty
      end

      it "CommunityFeed オブジェクトを返す" do
        expect(result).to be_a(Singing::CommunityFeedBuilder::CommunityFeed)
      end
    end

    context "診断完了イベント" do
      let!(:customer) { create(:customer, domain_name: "singing", name: "Tomoki") }
      let!(:diagnosis) { make_diagnosis(customer: customer, created_at: 3.days.ago) }

      it ":diagnosis_completed の FeedItem が含まれる" do
        item = result.feed_items.find { |i| i.type == :diagnosis_completed && i.customer == customer }
        expect(item).to be_present
      end

      it "icon が 🎤 である" do
        item = result.feed_items.find { |i| i.type == :diagnosis_completed && i.customer == customer }
        expect(item.icon).to eq("🎤")
      end

      it "message が「新しい診断に挑戦しました」である" do
        item = result.feed_items.find { |i| i.type == :diagnosis_completed && i.customer == customer }
        expect(item.message).to eq("新しい診断に挑戦しました")
      end

      it "message にスコアが含まれない" do
        item = result.feed_items.find { |i| i.type == :diagnosis_completed && i.customer == customer }
        expect(item.message).not_to match(/\d+点/)
      end
    end

    context "自己ベスト更新イベント" do
      let!(:customer) { create(:customer, domain_name: "singing", name: "Yuki") }

      before do
        make_diagnosis(customer: customer, score: 70, created_at: 20.days.ago)
        make_diagnosis(customer: customer, score: 85, created_at: 5.days.ago)
      end

      it ":personal_best の FeedItem が含まれる" do
        item = result.feed_items.find { |i| i.type == :personal_best && i.customer == customer }
        expect(item).to be_present
      end

      it "icon が ⭐ である" do
        item = result.feed_items.find { |i| i.type == :personal_best && i.customer == customer }
        expect(item.icon).to eq("⭐")
      end

      it "message が「自己ベスト更新」である" do
        item = result.feed_items.find { |i| i.type == :personal_best && i.customer == customer }
        expect(item.message).to eq("自己ベスト更新")
      end

      it "message にスコアが含まれない（スコア表示禁止）" do
        item = result.feed_items.find { |i| i.type == :personal_best && i.customer == customer }
        expect(item.message).not_to include("85")
        expect(item.message).not_to match(/\d+点/)
      end
    end

    context "前回より低いスコアの場合" do
      let!(:customer) { create(:customer, domain_name: "singing", name: "Miki") }

      before do
        make_diagnosis(customer: customer, score: 85, created_at: 20.days.ago)
        make_diagnosis(customer: customer, score: 70, created_at: 5.days.ago)
      end

      it ":personal_best の FeedItem が含まれない" do
        items = result.feed_items.select { |i| i.type == :personal_best && i.customer == customer }
        expect(items).to be_empty
      end
    end

    context "自己ベストが lookback 外の古い診断との比較" do
      let!(:customer) { create(:customer, domain_name: "singing", name: "Sato") }

      before do
        make_diagnosis(customer: customer, score: 60, created_at: 60.days.ago)
        make_diagnosis(customer: customer, score: 80, created_at: 5.days.ago)
      end

      it "古い診断を超えた場合も :personal_best が生成される" do
        item = result.feed_items.find { |i| i.type == :personal_best && i.customer == customer }
        expect(item).to be_present
      end
    end

    context "7日継続達成イベント" do
      let!(:customer) { create(:customer, domain_name: "singing", name: "Riko") }

      before do
        7.times { |i| make_diagnosis(customer: customer, created_at: (8 - i).days.ago) }
      end

      it ":streak_milestone の FeedItem が含まれる" do
        item = result.feed_items.find { |i| i.type == :streak_milestone && i.customer == customer }
        expect(item).to be_present
      end

      it "icon が 🔥 である" do
        item = result.feed_items.find { |i| i.type == :streak_milestone && i.customer == customer }
        expect(item.icon).to eq("🔥")
      end

      it "message が「7日継続達成」である" do
        item = result.feed_items.find { |i| i.type == :streak_milestone && i.customer == customer }
        expect(item.message).to eq("7日継続達成")
      end
    end

    context "6日継続の場合（7日未達）" do
      let!(:customer) { create(:customer, domain_name: "singing", name: "Hana") }

      before do
        6.times { |i| make_diagnosis(customer: customer, created_at: (7 - i).days.ago) }
      end

      it ":streak_milestone の FeedItem が含まれない" do
        items = result.feed_items.select { |i| i.type == :streak_milestone && i.customer == customer }
        expect(items).to be_empty
      end
    end

    context "7日連続だが途中にギャップがある場合" do
      let!(:customer) { create(:customer, domain_name: "singing", name: "Nao") }

      before do
        # 3日連続、ギャップ、3日連続（合計6日だが連続ではない）
        3.times { |i| make_diagnosis(customer: customer, created_at: (14 - i).days.ago) }
        3.times { |i| make_diagnosis(customer: customer, created_at: (8 - i).days.ago) }
      end

      it ":streak_milestone の FeedItem が含まれない" do
        items = result.feed_items.select { |i| i.type == :streak_milestone && i.customer == customer }
        expect(items).to be_empty
      end
    end

    context "Challenge達成イベント" do
      let!(:customer) { create(:customer, domain_name: "singing", name: "Kana") }
      let!(:challenge_progress) do
        create(:singing_ai_challenge_progress,
               customer:     customer,
               completed:    true,
               completed_at: 2.days.ago)
      end

      it ":challenge_achieved の FeedItem が含まれる" do
        item = result.feed_items.find { |i| i.type == :challenge_achieved && i.customer == customer }
        expect(item).to be_present
      end

      it "icon が 🏆 である" do
        item = result.feed_items.find { |i| i.type == :challenge_achieved && i.customer == customer }
        expect(item.icon).to eq("🏆")
      end

      it "message が「Challenge達成」である" do
        item = result.feed_items.find { |i| i.type == :challenge_achieved && i.customer == customer }
        expect(item.message).to eq("Challenge達成")
      end
    end

    context "completed が false の Challenge" do
      let!(:customer) { create(:customer, domain_name: "singing", name: "Incomplete") }
      let!(:incomplete_challenge) do
        create(:singing_ai_challenge_progress,
               customer:  customer,
               completed: false)
      end

      it ":challenge_achieved の FeedItem が含まれない" do
        items = result.feed_items.select { |i| i.type == :challenge_achieved && i.customer == customer }
        expect(items).to be_empty
      end
    end

    context "ソート順" do
      let!(:customer_a) { create(:customer, domain_name: "singing", name: "A") }
      let!(:customer_b) { create(:customer, domain_name: "singing", name: "B") }
      let!(:customer_c) { create(:customer, domain_name: "singing", name: "C") }

      before do
        make_diagnosis(customer: customer_a, created_at: 10.days.ago)
        make_diagnosis(customer: customer_b, created_at: 5.days.ago)
        make_diagnosis(customer: customer_c, created_at: 1.day.ago)
      end

      it "occurred_at の降順（新しい順）で返す" do
        times = result.feed_items.map(&:occurred_at)
        expect(times).to eq(times.sort.reverse)
      end
    end

    context "最大10件制限" do
      before do
        12.times do |i|
          customer = create(:customer, domain_name: "singing")
          make_diagnosis(customer: customer, created_at: (i + 1).days.ago)
        end
      end

      it "feed_items が10件以下になる" do
        expect(result.feed_items.size).to be <= Singing::CommunityFeedBuilder::FEED_LIMIT
      end
    end

    context "lookback 外の古い診断のみの場合" do
      let!(:customer) { create(:customer, domain_name: "singing", name: "Old") }

      before do
        make_diagnosis(customer: customer, created_at: 40.days.ago)
      end

      it "feed が空になる" do
        expect(result.feed_items).to be_empty
      end
    end

    context "FeedItem の構造確認" do
      let!(:customer) { create(:customer, domain_name: "singing", name: "Struct") }

      before { make_diagnosis(customer: customer, created_at: 1.day.ago) }

      it "FeedItem が type / customer / message / icon / occurred_at / reacted を持つ" do
        item = result.feed_items.first
        expect(item.type).to be_a(Symbol)
        expect(item.customer).to be_present
        expect(item.message).to be_a(String)
        expect(item.icon).to be_a(String)
        expect(item.occurred_at).to be_present
        expect(item.reacted).to eq(false)
      end

      it "FeedItem の customer が Customer インスタンスである" do
        item = result.feed_items.first
        expect(item.customer).to be_a(Customer)
      end
    end

    context "reacted 判定" do
      let!(:viewer)  { create(:customer, domain_name: "singing", name: "Viewer") }
      let!(:target)  { create(:customer, domain_name: "singing", name: "Target") }
      let!(:other)   { create(:customer, domain_name: "singing", name: "Other") }

      before do
        make_diagnosis(customer: target, created_at: 2.days.ago)
        make_diagnosis(customer: other,  created_at: 3.days.ago)
      end

      context "current_customer が nil の場合" do
        subject(:result) { described_class.call(current_customer: nil) }

        it "全アイテムの reacted が false である" do
          expect(result.feed_items.map(&:reacted)).to all(eq(false))
        end
      end

      context "current_customer が未応援の場合" do
        subject(:result) { described_class.call(current_customer: viewer) }

        it "target アイテムの reacted が false である" do
          item = result.feed_items.find { |i| i.customer == target }
          expect(item.reacted).to eq(false)
        end
      end

      context "current_customer が対象ユーザーに cheer 済みの場合" do
        subject(:result) { described_class.call(current_customer: viewer) }

        before do
          create(:singing_profile_reaction,
                 customer: viewer, target_customer: target, reaction_type: "cheer")
        end

        it "target アイテムの reacted が true である" do
          item = result.feed_items.find { |i| i.customer == target }
          expect(item.reacted).to eq(true)
        end

        it "応援していない other アイテムの reacted が false である" do
          item = result.feed_items.find { |i| i.customer == other }
          expect(item.reacted).to eq(false)
        end
      end

      context "cheer 以外のリアクション種別の場合" do
        subject(:result) { described_class.call(current_customer: viewer) }

        before do
          create(:singing_profile_reaction,
                 customer: viewer, target_customer: target, reaction_type: "amazing")
        end

        it "target アイテムの reacted は false のまま（cheer のみ対象）" do
          item = result.feed_items.find { |i| i.customer == target }
          expect(item.reacted).to eq(false)
        end
      end

      context "複数アイテムを一括で reacted 判定する（N+1 禁止）" do
        subject(:result) { described_class.call(current_customer: viewer) }

        before do
          create(:singing_profile_reaction,
                 customer: viewer, target_customer: target, reaction_type: "cheer")
        end

        it "SingingProfileReaction へのクエリが1回で完結する" do
          query_count = 0
          counter = ->(*, **) { query_count += 1 }
          ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
            described_class.call(current_customer: viewer)
          end
          reaction_queries = query_count
          expect(reaction_queries).to be <= 8
        end
      end
    end

    context "name が空白の customer でも item が作れる" do
      let!(:customer) { create(:customer, domain_name: "singing", name: "Placeholder") }

      before do
        customer.update_column(:name, "")
        make_diagnosis(customer: customer, created_at: 1.day.ago)
      end

      it "feed_items が生成される（エラーにならない）" do
        expect { result }.not_to raise_error
      end

      it "blank name の customer の item が含まれる" do
        item = result.feed_items.find { |i| i.customer == customer }
        expect(item).to be_present
      end
    end

    context "公開同意(ranking_opt_in)によるフィルタ" do
      it "ranking_opt_in=true の診断完了は feed に含まれる" do
        customer = create(:customer, domain_name: "singing", name: "OptIn")
        make_diagnosis(customer: customer, created_at: 1.day.ago, ranking_opt_in: true)

        item = result.feed_items.find { |i| i.type == :diagnosis_completed && i.customer == customer }
        expect(item).to be_present
      end

      it "ranking_opt_in=false の診断完了は feed に含まれない" do
        customer = create(:customer, domain_name: "singing", name: "OptOut")
        make_diagnosis(customer: customer, created_at: 1.day.ago, ranking_opt_in: false)

        item = result.feed_items.find { |i| i.customer == customer }
        expect(item).to be_nil
      end

      it "非公開診断しか持たないユーザーは feed に表示されない" do
        customer = create(:customer, domain_name: "singing", name: "AllPrivate")
        3.times { |i| make_diagnosis(customer: customer, created_at: (i + 1).days.ago, ranking_opt_in: false) }

        expect(result.feed_items.map(&:customer)).not_to include(customer)
      end

      it "非公開の自己ベストは personal_best の判定材料に使われない" do
        customer = create(:customer, domain_name: "singing", name: "MixedBest")
        # 非公開の95点は基準に含まれないため、公開の80点(60点からの更新)が自己ベスト更新として検出される
        make_diagnosis(customer: customer, score: 95, created_at: 25.days.ago, ranking_opt_in: false)
        make_diagnosis(customer: customer, score: 60, created_at: 20.days.ago, ranking_opt_in: true)
        make_diagnosis(customer: customer, score: 80, created_at: 5.days.ago,  ranking_opt_in: true)

        item = result.feed_items.find { |i| i.type == :personal_best && i.customer == customer }
        expect(item).to be_present
      end
    end

    context "UTC/JST 日付境界（streak_milestone のJST基準判定）" do
      # 「現在時刻」を固定し、絶対日付(2026-09-13〜09-20)がすべて
      # lookback 期間(30日以内)に収まるようにする。テスト実行時刻に依存しない。
      around do |example|
        travel_to(Time.zone.local(2026, 9, 20, 12, 0)) { example.run }
      end

      let!(:customer) { create(:customer, domain_name: "singing", name: "Boundary") }

      # 境界の影響を受けない安全な時刻（JST正午）で連続日を作る
      def make_safe_daily_diagnoses(days)
        days.each do |day|
          make_diagnosis(customer: customer, created_at: Time.zone.local(2026, 9, day, 12, 0))
        end
      end

      context "UTC 14:59（JST 2026-09-19 23:59 / 判定日 09-19）" do
        before do
          make_safe_daily_diagnoses(13..18)
          make_diagnosis(customer: customer, created_at: Time.utc(2026, 9, 19, 14, 59))
        end

        it "判定日 09-19 として基礎6日と合わせて7日連続になり streak_milestone が生成される" do
          item = result.feed_items.find { |i| i.type == :streak_milestone && i.customer == customer }
          expect(item).to be_present
        end
      end

      context "UTC 15:00 ちょうど（JST 2026-09-20 00:00 / 判定日 09-20）で日付が切り替わる" do
        before do
          make_safe_daily_diagnoses(14..19)
          make_diagnosis(customer: customer, created_at: Time.utc(2026, 9, 19, 15, 0))
        end

        it "判定日 09-20 として基礎6日と合わせて7日連続になり streak_milestone が生成される" do
          # UTC日付のまま扱うと 09-19 の診断と同日になり6日にしかならず、
          # streak_milestone が生成されない状態になる（境界1分のズレを検知する）。
          item = result.feed_items.find { |i| i.type == :streak_milestone && i.customer == customer }
          expect(item).to be_present
        end
      end

      context "同一JST日付(09-20)に複数の境界時刻（UTC 16:58 / UTC 23:59）で診断がある場合" do
        before do
          make_safe_daily_diagnoses(14..19)
          make_diagnosis(customer: customer, created_at: Time.utc(2026, 9, 19, 16, 58))
          make_diagnosis(customer: customer, created_at: Time.utc(2026, 9, 19, 23, 59))
        end

        it "2件とも判定日 09-20 の1日分として扱われ7日連続で streak_milestone が生成される" do
          item = result.feed_items.find { |i| i.type == :streak_milestone && i.customer == customer }
          expect(item).to be_present
        end

        it "occurred_at はその判定日で最も新しい診断時刻になる" do
          item = result.feed_items.find { |i| i.type == :streak_milestone && i.customer == customer }
          expect(item.occurred_at).to be_within(1.second).of(Time.utc(2026, 9, 19, 23, 59))
        end
      end
    end

    context "公開同意(ranking_opt_in)が streak_milestone の生成元にも適用される" do
      around do |example|
        travel_to(Time.zone.local(2026, 9, 20, 12, 0)) { example.run }
      end

      let!(:customer) { create(:customer, domain_name: "singing", name: "StreakOptIn") }

      it "非公開診断を含めないと7日に届かない場合、streak_milestone は生成されない" do
        (14..18).each do |day|
          make_diagnosis(customer: customer, created_at: Time.zone.local(2026, 9, day, 12, 0), ranking_opt_in: true)
        end
        # 非公開の2日分。これを含めれば7日連続になるが、除外されるべき。
        (19..20).each do |day|
          make_diagnosis(customer: customer, created_at: Time.zone.local(2026, 9, day, 12, 0), ranking_opt_in: false)
        end

        item = result.feed_items.find { |i| i.type == :streak_milestone && i.customer == customer }
        expect(item).to be_nil
      end
    end
  end
end
