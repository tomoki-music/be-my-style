require "rails_helper"

RSpec.describe "Singing::Badges", type: :request do
  let(:customer) { create(:customer, domain_name: "singing") }
  let(:other_customer) { create(:customer, domain_name: "singing") }

  # ── GET /singing/badges ────────────────────────────────────────────────────

  describe "GET /singing/badges" do
    context "未ログインの場合" do
      it "ログインページへリダイレクトされること" do
        get singing_badges_path

        expect(response).to redirect_to(new_customer_session_path)
      end
    end

    context "ログイン済みの場合" do
      before { sign_in customer }

      it "バッジ一覧ページが表示されること" do
        get singing_badges_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("あなたのバッジ")
        expect(response.body).to include("実績バッジ")
        expect(response.body).to include("シーズンバッジ")
      end

      it "全12種類の実績バッジ定義が表示されること" do
        get singing_badges_path

        Singing::RankingBadgeService::BADGE_DEFINITIONS.each_value do |definition|
          expect(response.body).to include(definition[:label])
        end
      end

      it "バッジ未取得の場合、実績バッジはすべて「未獲得」で表示されること" do
        get singing_badges_path

        expect(response.body).to include("未獲得")
        expect(response.body).not_to include("singing-badges__ranking-badge--unearned\">")
      end

      it "診断を1件完了するとその実績バッジが獲得済みになること" do
        create(:singing_diagnosis, :completed, customer: customer, overall_score: 75)

        get singing_badges_path

        expect(response.body).to include("初診断")
        body = response.body
        expect(body).to include("実績バッジ")
      end

      it "獲得済みシーズンバッジが一覧に表示されること" do
        season = create(
          :singing_ranking_season,
          name: "2026年4月シーズン",
          status: "closed",
          starts_on: Date.new(2026, 4, 1),
          ends_on: Date.new(2026, 4, 30)
        )
        create(
          :singing_badge,
          customer: customer,
          singing_ranking_season: season,
          badge_type: "season_1st",
          awarded_at: 2.days.ago
        )

        get singing_badges_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("今月の王者")
        expect(response.body).to include("🥇")
        expect(response.body).to include("2026年4月シーズン")
        expect(response.body).to include("NEW")
      end

      it "7日より古いシーズンバッジには NEW が表示されないこと" do
        season = create(
          :singing_ranking_season,
          name: "2026年3月シーズン",
          status: "closed",
          starts_on: Date.new(2026, 3, 1),
          ends_on: Date.new(2026, 3, 31)
        )
        create(
          :singing_badge,
          customer: customer,
          singing_ranking_season: season,
          badge_type: "rapid_growth",
          awarded_at: 10.days.ago
        )

        get singing_badges_path

        expect(response.body).to include("急成長シンガー")
        expect(response.body).not_to include("NEW")
      end

      it "シーズンバッジがない場合は空状態メッセージを表示すること" do
        get singing_badges_path

        expect(response.body).to include("シーズンバッジはまだありません。")
        expect(response.body).to include("ランキングに参加する")
      end

      it "複数シーズンのバッジがあってもページが正常に表示されること（N+1対策確認）" do
        season_a = create(
          :singing_ranking_season,
          name: "2026年2月シーズン",
          status: "closed",
          starts_on: Date.new(2026, 2, 1),
          ends_on: Date.new(2026, 2, 28)
        )
        season_b = create(
          :singing_ranking_season,
          name: "2026年3月シーズン",
          status: "closed",
          starts_on: Date.new(2026, 3, 1),
          ends_on: Date.new(2026, 3, 31)
        )
        create(:singing_badge, customer: customer, singing_ranking_season: season_a,
                               badge_type: "season_1st", awarded_at: 60.days.ago)
        create(:singing_badge, customer: customer, singing_ranking_season: season_b,
                               badge_type: "season_2nd", awarded_at: 30.days.ago)

        get singing_badges_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("2026年2月シーズン")
        expect(response.body).to include("2026年3月シーズン")
        expect(response.body).to include("今月の王者")
        expect(response.body).to include("準優勝")
      end

      context "次に狙えるバッジ" do
        it "診断未実施の場合、次に狙えるバッジセクションが表示されること" do
          get singing_badges_path

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("次に狙えるバッジ")
          expect(response.body).to include("あと")
          expect(response.body).to include("もう一度診断する")
          expect(response.body).to include("ランキングを見る")
        end

        it "次に狙えるバッジのヒントにバッジ名と進捗メッセージが含まれること" do
          get singing_badges_path

          hints = Singing::NextBadgeService.call(customer)
          expect(hints).not_to be_empty
          hints.each do |hint|
            expect(response.body).to include(hint.label)
            expect(response.body).to include(hint.description)
          end
        end

        it "NextBadgeService が空を返す場合、次に狙えるバッジセクションが表示されないこと" do
          allow(Singing::NextBadgeService).to receive(:call).and_return([])

          get singing_badges_path

          expect(response).to have_http_status(:ok)
          expect(response.body).not_to include("次に狙えるバッジ")
          expect(response.body).not_to include("もう一度診断する")
        end
      end

      context "Achievement Badge ギャラリー" do
        it "実績バッジセクションが表示されること" do
          get singing_badges_path

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Achievement Badges")
          expect(response.body).to include("実績バッジ")
        end

        it "全 MVP バッジのラベルが表示されること" do
          get singing_badges_path

          SingingAchievementBadge::BADGE_DEFINITIONS.each_value do |defn|
            expect(response.body).to include(defn[:label])
          end
        end

        it "バッジ未獲得の場合、すべて未獲得ラベルで表示されること" do
          get singing_badges_path

          expect(response.body).to include("未獲得")
          expect(response.body).to include("🔒")
        end

        it "獲得済みバッジが獲得済みラベルで表示されること" do
          create(:singing_achievement_badge, :first_diagnosis, customer: customer,
                 earned_at: Time.zone.local(2026, 5, 15))

          get singing_badges_path

          expect(response.body).to include("獲得済み")
          expect(response.body).to include("5月15日 達成")
          expect(response.body).to include("First Note")
        end

        it "コンプリート率が表示されること" do
          get singing_badges_path

          expect(response.body).to include("0%")
          expect(response.body).to include("0")
          expect(response.body).to include(SingingAchievementBadge::BADGE_DEFINITIONS.size.to_s)
        end

        it "category フィルターが効くこと（milestone のみ表示）" do
          get singing_badges_path(category: "milestone")

          expect(response.body).to include("First Note")     # milestone
          expect(response.body).to include("10 Songs")       # milestone
          expect(response.body).not_to include("7 Day Streak") # streak
        end

        it "rarity フィルターが効くこと（rare のみ表示）" do
          get singing_badges_path(rarity: "rare")

          expect(response.body).to include("7 Day Streak")   # rare
          expect(response.body).to include("Score 90 Club")  # rare
          # epic カードが gallery セクションに表示されないこと（JSON データ属性への混入は許容）
          expect(response.body).not_to include("achievement-badge-card--epic")
        end

        it "他ユーザーの achievement badge は表示されないこと" do
          create(:singing_achievement_badge, :streak_7, customer: other_customer,
                 earned_at: Time.zone.local(2026, 5, 10))

          get singing_badges_path

          expect(response.body).not_to include("5月10日 達成")
        end

        it "当該ユーザーの achievement badge のみ表示されること" do
          create(:singing_achievement_badge, :first_diagnosis, customer: customer,
                 earned_at: Time.zone.local(2026, 5, 1))
          create(:singing_achievement_badge, :personal_best, customer: other_customer,
                 earned_at: Time.zone.local(2026, 5, 2))

          get singing_badges_path

          expect(response.body).to include("5月1日 達成")      # 自分のバッジ
          expect(response.body).not_to include("5月2日 達成") # 他人のバッジ
        end

        context "Free / Light ユーザーの場合" do
          before do
            allow(customer).to receive(:has_feature?).and_call_original
            allow(customer).to receive(:has_feature?)
              .with(:singing_achievement_badge_share_image).and_return(false)
          end

          it "シェアボタンが表示されずロック表示になること" do
            create(:singing_achievement_badge, :first_diagnosis, customer: customer)

            get singing_badges_path

            expect(response.body).to include("Coreプランでシェア")
            expect(response.body).not_to include("シェアする")
          end

          it "獲得済みバッジがある場合、Core プランへの課金 CTA が表示されること" do
            create(:singing_achievement_badge, :first_diagnosis, customer: customer)

            get singing_badges_path

            expect(response.body).to include("Coreプランにアップグレード")
            expect(response.body).to include("Coreプランを見る")
          end

          it "バッジ未獲得の場合、課金 CTA は表示されないこと" do
            get singing_badges_path

            expect(response.body).not_to include("Coreプランにアップグレード")
          end
        end

        context "Core / Premium ユーザーの場合" do
          before do
            allow(customer).to receive(:has_feature?).and_call_original
            allow(customer).to receive(:has_feature?)
              .with(:singing_achievement_badge_share_image).and_return(true)
          end

          it "獲得済みバッジにシェアボタンが表示されること" do
            create(:singing_achievement_badge, :first_diagnosis, customer: customer)

            get singing_badges_path

            expect(response.body).to include("シェアする")
            expect(response.body).not_to include("Coreプランでシェア")
          end

          it "課金 CTA が表示されないこと" do
            create(:singing_achievement_badge, :first_diagnosis, customer: customer)

            get singing_badges_path

            expect(response.body).not_to include("Coreプランにアップグレード")
          end
        end
      end

      context "NextBadgeHint バナー（Phase 2-B）" do
        it "進捗 > 0 のバッジがある場合、バナーが表示されること" do
          # diagnosis_10: 3回診断 → progress_ratio = 0.3 > 0
          3.times { create(:singing_diagnosis, :completed, customer: customer) }

          get singing_badges_path

          expect(response.body).to include("バッジ一覧 →")
        end

        it "progress がない場合（診断0回）、バナーが表示されないこと" do
          allow(Singing::NextBadgeHintAggregator).to receive(:call).and_return(nil)

          get singing_badges_path

          expect(response.body).not_to include("バッジ一覧 →")
        end

        it "is_close の場合「あと少し！」バッジが表示されること" do
          # streak_7: 6日連続 → ratio ≈ 0.857 >= 0.8 → is_close
          6.times { |i| create(:singing_diagnosis, :completed, customer: customer, created_at: (5 - i).days.ago) }

          get singing_badges_path

          close_result = Singing::NextBadgeHintAggregator.call(
            customer,
            earned_badge_keys: customer.singing_achievement_badges.pluck(:badge_key).to_set
          )
          if close_result&.is_close
            expect(response.body).to include("あと少し！")
          end
        end
      end

      context "ProgressHint（未獲得カード）" do
        it "達成率50%以上の未獲得バッジにhint_textが表示されること" do
          # diagnosis_10: 5回 → ratio = 0.5 → 表示対象
          5.times { create(:singing_diagnosis, :completed, customer: customer) }

          get singing_badges_path

          expect(response.body).to include("あと5回で「10 Songs」")
        end

        it "達成率50%未満の場合はhint_textが表示されないこと" do
          # diagnosis_10: 0回 → ratio = 0.0 → locked_description のみ
          get singing_badges_path

          expect(response.body).to include("診断を累計10回完了すると獲得できます")
          expect(response.body).not_to include("あと10回で「10 Songs」")
        end

        it "獲得済みバッジにはProgressHintが表示されないこと" do
          create(:singing_achievement_badge, :diagnosis_10, customer: customer)
          9.times { create(:singing_diagnosis, :completed, customer: customer) }

          get singing_badges_path

          # diagnosis_10 は獲得済みなので hint が表示されない
          expect(response.body).not_to include("あと1回で「10 Songs」")
        end
      end

      context "Timeline 導線（Phase 2-J）" do
        it "Achievement Timeline へのリンクが表示されること" do
          get singing_badges_path

          expect(response.body).to include("Achievement Timeline")
          expect(response.body).to include(timeline_singing_badges_path)
        end
      end
    end
  end

  # ── GET /singing/badges/monthly_wrapped ───────────────────────────────────

  describe "GET /singing/badges/monthly_wrapped" do
    context "未ログインの場合" do
      it "ログインページへリダイレクトされること" do
        get monthly_wrapped_singing_badges_path

        expect(response).to redirect_to(new_customer_session_path)
      end
    end

    context "ログイン済みの場合" do
      before { sign_in customer }

      it "monthly_wrapped ページが表示されること" do
        create(:singing_achievement_badge, :first_diagnosis, customer: customer,
               earned_at: Time.zone.local(2026, 5, 10, 10, 0, 0))
        get monthly_wrapped_singing_badges_path(month: "2026-05")

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Monthly Achievement Wrapped")
        expect(response.body).to include("2026年5月のAchievement Wrapped")
      end

      it "month 未指定でもページが表示されること（当月がデフォルト）" do
        get monthly_wrapped_singing_badges_path

        expect(response).to have_http_status(:ok)
      end

      context "指定月にバッジがない場合（空状態）" do
        it "空状態メッセージが表示されること" do
          get monthly_wrapped_singing_badges_path(month: "2026-05")

          expect(response.body).to include("2026年5月のAchievementはまだありません")
          expect(response.body).to include("Timelineに戻って、これまでの挑戦を振り返ってみましょう。")
        end

        it "Timeline へのリンクが表示されること" do
          get monthly_wrapped_singing_badges_path(month: "2026-05")

          expect(response.body).to include(timeline_singing_badges_path)
        end
      end

      context "指定月にバッジがある場合" do
        let!(:badge_first) do
          create(:singing_achievement_badge, :first_diagnosis, customer: customer,
                 earned_at: Time.zone.local(2026, 5, 5, 10, 0, 0))
        end
        let!(:badge_streak) do
          create(:singing_achievement_badge, :streak_7, customer: customer,
                 earned_at: Time.zone.local(2026, 5, 20, 10, 0, 0))
        end

        it "指定月のバッジが表示されること" do
          get monthly_wrapped_singing_badges_path(month: "2026-05")

          expect(response.body).to include("First Note")
          expect(response.body).to include("7 Day Streak")
        end

        it "月タイトルが表示されること" do
          get monthly_wrapped_singing_badges_path(month: "2026-05")

          expect(response.body).to include("2026年5月のAchievement Wrapped")
        end

        it "月ラベルが表示されること" do
          get monthly_wrapped_singing_badges_path(month: "2026-05")

          expect(response.body).to include("挑戦が形になった月")
        end

        it "獲得数が表示されること" do
          get monthly_wrapped_singing_badges_path(month: "2026-05")

          expect(response.body).to include("2")
          expect(response.body).to include("件の達成")
        end

        it "Timeline へ戻るリンクが表示されること" do
          get monthly_wrapped_singing_badges_path(month: "2026-05")

          expect(response.body).to include("Achievement Timeline")
          expect(response.body).to include(timeline_singing_badges_path)
        end

        context "Core ユーザーはシェアカード導線が表示されること" do
          before { customer.create_subscription!(status: "active", plan: "core") }

          it "シェアカードを作るボタンが表示されること" do
            get monthly_wrapped_singing_badges_path(month: "2026-05")

            expect(response.body).to include("シェアカードを作る")
            expect(response.body).to include("target=monthly-achievement-wrapped")
            expect(response.body).to include("month=2026-05")
            expect(response.body).to include("Core / Premium")
          end

          it "アップグレード CTA は表示されないこと" do
            get monthly_wrapped_singing_badges_path(month: "2026-05")

            expect(response.body).not_to include("シェアカードは Core / Premium で利用できます")
          end
        end

        context "Free ユーザーには押し売り感のないアップグレード導線が表示されること" do
          it "アップグレード CTA が表示されること" do
            get monthly_wrapped_singing_badges_path(month: "2026-05")

            expect(response.body).to include("シェアカードは Core / Premium で利用できます")
            expect(response.body).to include("プランを見る")
            expect(response.body).not_to include("シェアカードを作る")
          end
        end

        context "Light ユーザーにもアップグレード CTA が表示されること" do
          before { customer.create_subscription!(status: "active", plan: "light") }

          it "アップグレード CTA が表示されること" do
            get monthly_wrapped_singing_badges_path(month: "2026-05")

            expect(response.body).to include("シェアカードは Core / Premium で利用できます")
            expect(response.body).not_to include("シェアカードを作る")
          end
        end
      end

      context "他月のバッジは表示されないこと" do
        let!(:badge_may) do
          create(:singing_achievement_badge, :first_diagnosis, customer: customer,
                 earned_at: Time.zone.local(2026, 5, 10, 10, 0, 0))
        end
        let!(:badge_apr) do
          create(:singing_achievement_badge, :personal_best, customer: customer,
                 earned_at: Time.zone.local(2026, 4, 15, 10, 0, 0))
        end

        it "5月のバッジのみ表示されること" do
          get monthly_wrapped_singing_badges_path(month: "2026-05")

          expect(response.body).to include("First Note")
          expect(response.body).not_to include("Personal Best")
        end
      end

      context "他ユーザーのバッジは表示されないこと" do
        let!(:my_badge) do
          create(:singing_achievement_badge, :first_diagnosis, customer: customer,
                 earned_at: Time.zone.local(2026, 5, 1, 10, 0, 0))
        end
        let!(:other_badge) do
          create(:singing_achievement_badge, :streak_7, customer: other_customer,
                 earned_at: Time.zone.local(2026, 5, 1, 10, 0, 0))
        end

        it "自分のバッジのみ表示されること" do
          get monthly_wrapped_singing_badges_path(month: "2026-05")

          expect(response.body).to include("First Note")
          expect(response.body).not_to include("7 Day Streak")
        end
      end
    end
  end

  # ── GET /singing/badges/yearly_rewind ────────────────────────────────────

  describe "GET /singing/badges/yearly_rewind" do
    context "未ログインの場合" do
      it "ログインページへリダイレクトされること" do
        get yearly_rewind_singing_badges_path

        expect(response).to redirect_to(new_customer_session_path)
      end
    end

    context "ログイン済みの場合" do
      before { sign_in customer }

      it "year 未指定でもページが表示されること" do
        get yearly_rewind_singing_badges_path

        expect(response).to have_http_status(:ok)
      end

      it "year 指定でページが表示されること" do
        get yearly_rewind_singing_badges_path(year: "2026")

        expect(response).to have_http_status(:ok)
      end

      context "指定年にバッジがない場合（空状態）" do
        it "空状態メッセージが表示されること" do
          get yearly_rewind_singing_badges_path(year: "2026")

          expect(response.body).to include("2026年のAchievementはまだありません")
          expect(response.body).to include("バッジを獲得すると、ここに1年間の達成がまとめて振り返れます。")
        end

        it "診断・バッジ一覧への導線が表示されること" do
          get yearly_rewind_singing_badges_path(year: "2026")

          expect(response.body).to include("バッジ一覧へ")
          expect(response.body).to include("診断を始める")
        end
      end

      context "指定年にバッジがある場合" do
        let!(:badge_jan) do
          create(:singing_achievement_badge, :first_diagnosis, customer: customer,
                 earned_at: Time.zone.local(2026, 1, 10, 10, 0, 0))
        end
        let!(:badge_may) do
          create(:singing_achievement_badge, :streak_7, customer: customer,
                 earned_at: Time.zone.local(2026, 5, 20, 10, 0, 0))
        end

        it "Yearly Achievement Rewind ページが表示されること" do
          get yearly_rewind_singing_badges_path(year: "2026")

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Yearly Achievement Rewind")
          expect(response.body).to include("2026年のAchievement Rewind")
        end

        it "獲得数が表示されること" do
          get yearly_rewind_singing_badges_path(year: "2026")

          expect(response.body).to include("2")
          expect(response.body).to include("件の達成")
        end

        it "バッジラベルが表示されること" do
          get yearly_rewind_singing_badges_path(year: "2026")

          expect(response.body).to include("First Note")
          expect(response.body).to include("7 Day Streak")
        end

        it "Monthly Highlights セクションが表示されること" do
          get yearly_rewind_singing_badges_path(year: "2026")

          expect(response.body).to include("Monthly Highlights")
          expect(response.body).to include("1月")
          expect(response.body).to include("5月")
        end

        it "Monthly Wrapped への導線が含まれること" do
          get yearly_rewind_singing_badges_path(year: "2026")

          expect(response.body).to include(monthly_wrapped_singing_badges_path(month: "2026-01"))
          expect(response.body).to include(monthly_wrapped_singing_badges_path(month: "2026-05"))
        end

        it "Timeline へ戻るリンクが表示されること" do
          get yearly_rewind_singing_badges_path(year: "2026")

          expect(response.body).to include("Achievement Timeline")
          expect(response.body).to include(timeline_singing_badges_path)
        end

        it "他年のバッジは表示されないこと" do
          create(:singing_achievement_badge, :personal_best, customer: customer,
                 earned_at: Time.zone.local(2025, 12, 31, 10, 0, 0))

          get yearly_rewind_singing_badges_path(year: "2026")

          expect(response.body).not_to include("12月")
        end

        it "他ユーザーのバッジは表示されないこと" do
          create(:singing_achievement_badge, :streak_30, customer: other_customer,
                 earned_at: Time.zone.local(2026, 3, 10, 10, 0, 0))

          get yearly_rewind_singing_badges_path(year: "2026")

          expect(response.body).not_to include("Monthly Devotee")
        end

        context "Core ユーザーはシェアカード導線が表示されること" do
          before { customer.create_subscription!(status: "active", plan: "core") }

          it "シェアカードを作るボタンが表示されること" do
            get yearly_rewind_singing_badges_path(year: "2026")

            expect(response.body).to include("シェアカードを作る")
            expect(response.body).to include("target=yearly-achievement-rewind")
            expect(response.body).to include("year=2026")
            expect(response.body).to include("Core / Premium")
          end

          it "アップグレード CTA は表示されないこと" do
            get yearly_rewind_singing_badges_path(year: "2026")

            expect(response.body).not_to include("シェアカードは Core / Premium で利用できます")
          end
        end

        context "Free ユーザーにはアップグレード導線が表示されること" do
          it "アップグレード CTA が表示されること" do
            get yearly_rewind_singing_badges_path(year: "2026")

            expect(response.body).to include("シェアカードは Core / Premium で利用できます")
            expect(response.body).not_to include("シェアカードを作る")
          end
        end
      end

      context "不正な year パラメータ" do
        it "year=0 は当年にフォールバックすること" do
          get yearly_rewind_singing_badges_path(year: "0")

          expect(response).to have_http_status(:ok)
        end

        it "year=abc は当年にフォールバックすること" do
          get yearly_rewind_singing_badges_path(year: "abc")

          expect(response).to have_http_status(:ok)
        end
      end
    end
  end

  # ── GET /singing/badges/timeline ──────────────────────────────────────────

  describe "GET /singing/badges/timeline" do
    context "未ログインの場合" do
      it "ログインページへリダイレクトされること" do
        get timeline_singing_badges_path

        expect(response).to redirect_to(new_customer_session_path)
      end
    end

    context "ログイン済みの場合" do
      before { sign_in customer }

      it "Timeline ページが表示されること" do
        get timeline_singing_badges_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Achievement Timeline")
        expect(response.body).to include("これまで積み重ねてきた挑戦の記録です。")
      end

      it "獲得済みバッジがない場合に空状態メッセージが表示されること" do
        get timeline_singing_badges_path

        expect(response.body).to include("まだTimelineは始まったばかりです。")
        expect(response.body).to include("最初の診断を完了すると、ここにあなたのAchievementが刻まれます。")
      end

      it "獲得済みバッジがある場合にバッジ情報が表示されること" do
        create(:singing_achievement_badge, :first_diagnosis, customer: customer,
               earned_at: Time.zone.local(2026, 5, 10))

        get timeline_singing_badges_path

        expect(response.body).to include("First Note")
        expect(response.body).to include("2026年5月")
        expect(response.body).to include("5月10日 達成")
      end

      it "月単位でグループ化されて表示されること" do
        create(:singing_achievement_badge, :first_diagnosis, customer: customer,
               earned_at: Time.zone.local(2026, 5, 10))
        create(:singing_achievement_badge, :personal_best, customer: customer,
               earned_at: Time.zone.local(2026, 4, 15))

        get timeline_singing_badges_path

        expect(response.body).to include("2026年5月")
        expect(response.body).to include("2026年4月")
      end

      it "月のラベルが表示されること" do
        create(:singing_achievement_badge, :first_diagnosis, customer: customer,
               earned_at: Time.zone.local(2026, 5, 1))

        get timeline_singing_badges_path

        expect(response.body).to include("挑戦が形になった月")
      end

      it "バッジ一覧ページへの戻りリンクがあること" do
        get timeline_singing_badges_path

        expect(response.body).to include("バッジ一覧")
        expect(response.body).to include(singing_badges_path)
      end

      it "他ユーザーのバッジは表示されないこと" do
        create(:singing_achievement_badge, :streak_7, customer: other_customer,
               earned_at: Time.zone.local(2026, 5, 5))

        get timeline_singing_badges_path

        expect(response.body).not_to include("7 Day Streak")
        expect(response.body).to include("まだTimelineは始まったばかりです。")
      end

      it "バッジがある月に Monthly Wrapped 導線が表示されること" do
        create(:singing_achievement_badge, :first_diagnosis, customer: customer,
               earned_at: Time.zone.local(2026, 5, 10))

        get timeline_singing_badges_path

        expect(response.body).to include("この月を振り返る →")
        expect(response.body).to include(monthly_wrapped_singing_badges_path(month: "2026-05"))
      end
    end
  end

  # ── GET /singing/badges/recap_movie.json ──────────────────────────────────

  describe "GET /singing/badges/recap_movie.json" do
    context "未ログインの場合" do
      it "認証エラーになること（リダイレクトまたは401）" do
        get recap_movie_singing_badges_path(format: :json)

        expect(response.status).to be_in([302, 401])
      end
    end

    context "ログイン済みの場合" do
      before { sign_in customer }

      it "200 を返すこと" do
        get recap_movie_singing_badges_path(format: :json, year: "2026")

        expect(response).to have_http_status(:ok)
      end

      it "Content-Type が application/json であること" do
        get recap_movie_singing_badges_path(format: :json, year: "2026")

        expect(response.content_type).to match(%r{application/json})
      end

      context "バッジがない場合（empty）" do
        it "JSON が返ること" do
          get recap_movie_singing_badges_path(format: :json, year: "2026")

          json = JSON.parse(response.body, symbolize_names: true)
          expect(json[:empty]).to be true
          expect(json[:scenes]).to eq([])
          expect(json[:year]).to eq(2026)
        end
      end

      context "バッジがある場合" do
        let!(:badge_jan) do
          create(:singing_achievement_badge, :first_diagnosis, customer: customer,
                 earned_at: Time.zone.local(2026, 1, 10, 10, 0, 0))
        end
        let!(:badge_may) do
          create(:singing_achievement_badge, :streak_7, customer: customer,
                 earned_at: Time.zone.local(2026, 5, 20, 10, 0, 0))
        end

        it "scenes 配列が含まれること" do
          get recap_movie_singing_badges_path(format: :json, year: "2026")

          json = JSON.parse(response.body, symbolize_names: true)
          expect(json[:scenes]).to be_an(Array)
          expect(json[:scenes]).not_to be_empty
        end

        it "必須トップレベルキーが揃っていること" do
          get recap_movie_singing_badges_path(format: :json, year: "2026")

          json = JSON.parse(response.body, symbolize_names: true)
          expect(json.keys).to include(:year, :title, :subtitle, :total_duration, :empty, :scenes)
        end

        it "scene に必須フィールドが含まれること" do
          get recap_movie_singing_badges_path(format: :json, year: "2026")

          json  = JSON.parse(response.body, symbolize_names: true)
          scene = json[:scenes].first
          expect(scene.keys).to include(:index, :type, :title, :subtitle, :body, :duration, :emotion, :background_style, :badge)
        end

        it "他ユーザーのデータを返さないこと" do
          create(:singing_achievement_badge, :personal_best, customer: other_customer,
                 earned_at: Time.zone.local(2026, 3, 1, 10, 0, 0))

          get recap_movie_singing_badges_path(format: :json, year: "2026")

          json = JSON.parse(response.body)
          expect(json.to_json).not_to include("Personal Best")
        end
      end

      context "不正な year パラメータ" do
        it "year=0 でも 500 にならないこと" do
          get recap_movie_singing_badges_path(format: :json, year: "0")

          expect(response.status).not_to eq(500)
        end

        it "year=abc でも 500 にならないこと" do
          get recap_movie_singing_badges_path(format: :json, year: "abc")

          expect(response.status).not_to eq(500)
        end

        it "year 未指定でも JSON が返ること" do
          get recap_movie_singing_badges_path(format: :json)

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json["scenes"]).to be_an(Array)
        end
      end
    end
  end

  # ── POST /singing/badges/recap_movie_request ──────────────────────────────

  describe "POST /singing/badges/recap_movie_request" do
    let(:year) { Time.current.year }

    context "未ログインの場合" do
      it "ログインページへリダイレクトまたは401になること" do
        post recap_movie_request_singing_badges_path, params: { year: year }, as: :json

        expect(response.status).to be_in([302, 401])
      end
    end

    context "ログイン済みの場合" do
      before { sign_in customer }

      context "Achievementがない場合（empty_source）" do
        before do
          allow(Singing::AchievementRecapMovieBuilder).to receive(:call).and_return(
            instance_double("Singing::AchievementRecapMovieBuilder::Result", empty?: true)
          )
        end

        it "200を返すこと" do
          post recap_movie_request_singing_badges_path, params: { year: year }, as: :json

          expect(response).to have_http_status(:ok)
        end

        it "status が empty_source で movie が null であること" do
          post recap_movie_request_singing_badges_path, params: { year: year }, as: :json

          json = JSON.parse(response.body, symbolize_names: true)
          expect(json[:status]).to eq("empty_source")
          expect(json[:movie]).to be_nil
        end

        it "messageが含まれること" do
          post recap_movie_request_singing_badges_path, params: { year: year }, as: :json

          json = JSON.parse(response.body, symbolize_names: true)
          expect(json[:message]).to be_present
        end
      end

      context "新規リクエストの場合（created_pending）" do
        before do
          allow(Singing::AchievementRecapMovieBuilder).to receive(:call).and_return(
            instance_double("Singing::AchievementRecapMovieBuilder::Result", empty?: false)
          )
          allow(Singing::AchievementRecapMovieSerializer).to receive(:new).and_return(
            instance_double("Singing::AchievementRecapMovieSerializer", as_json: { scenes: [] })
          )
        end

        it "200を返すこと" do
          post recap_movie_request_singing_badges_path, params: { year: year }, as: :json

          expect(response).to have_http_status(:ok)
        end

        it "status が created_pending で movie が含まれること" do
          post recap_movie_request_singing_badges_path, params: { year: year }, as: :json

          json = JSON.parse(response.body, symbolize_names: true)
          expect(json[:status]).to eq("created_pending")
          expect(json[:movie]).to be_present
          expect(json[:movie][:year]).to eq(year)
          expect(json[:movie][:status]).to eq("pending")
          expect(json[:movie][:reusable]).to be false
          expect(json[:movie][:video_url]).to be_nil
        end

        it "DBにrecap movieレコードが作成されること" do
          expect {
            post recap_movie_request_singing_badges_path, params: { year: year }, as: :json
          }.to change(SingingGeneratedRecapMovie, :count).by(1)
        end
      end

      context "すでに pending 状態の場合（already_pending）" do
        let!(:existing_movie) { create(:singing_generated_recap_movie, customer: customer, year: year, status: :pending) }

        it "status が already_pending であること" do
          post recap_movie_request_singing_badges_path, params: { year: year }, as: :json

          json = JSON.parse(response.body, symbolize_names: true)
          expect(json[:status]).to eq("already_pending")
          expect(json[:movie][:id]).to eq(existing_movie.id)
        end

        it "新規レコードが作られないこと" do
          expect {
            post recap_movie_request_singing_badges_path, params: { year: year }, as: :json
          }.not_to change(SingingGeneratedRecapMovie, :count)
        end
      end

      context "すでに processing 状態の場合（already_processing）" do
        let!(:existing_movie) { create(:singing_generated_recap_movie, customer: customer, year: year, status: :processing) }

        it "status が already_processing であること" do
          post recap_movie_request_singing_badges_path, params: { year: year }, as: :json

          json = JSON.parse(response.body, symbolize_names: true)
          expect(json[:status]).to eq("already_processing")
        end
      end

      context "completed かつ reusable な場合（reused_completed）" do
        let!(:existing_movie) { create(:singing_generated_recap_movie, :completed, customer: customer, year: year) }

        it "status が reused_completed であること" do
          post recap_movie_request_singing_badges_path, params: { year: year }, as: :json

          json = JSON.parse(response.body, symbolize_names: true)
          expect(json[:status]).to eq("reused_completed")
          expect(json[:movie][:reusable]).to be true
        end
      end

      context "不正な year パラメータ" do
        before do
          allow(Singing::AchievementRecapMovieBuilder).to receive(:call).and_return(
            instance_double("Singing::AchievementRecapMovieBuilder::Result", empty?: true)
          )
        end

        it "year=0 でも 500 にならないこと" do
          post recap_movie_request_singing_badges_path, params: { year: "0" }, as: :json

          expect(response.status).not_to eq(500)
        end

        it "year=abc でも 500 にならないこと" do
          post recap_movie_request_singing_badges_path, params: { year: "abc" }, as: :json

          expect(response.status).not_to eq(500)
        end

        it "year 未指定でも JSON が返ること" do
          post recap_movie_request_singing_badges_path, as: :json

          expect(response.status).not_to eq(500)
          json = JSON.parse(response.body)
          expect(json["status"]).to be_present
        end
      end

      context "レスポンス構造" do
        before do
          allow(Singing::AchievementRecapMovieBuilder).to receive(:call).and_return(
            instance_double("Singing::AchievementRecapMovieBuilder::Result", empty?: true)
          )
        end

        it "status / message / movie / queued キーが含まれること" do
          post recap_movie_request_singing_badges_path, params: { year: year }, as: :json

          json = JSON.parse(response.body, symbolize_names: true)
          expect(json.keys).to include(:status, :message, :movie, :queued)
        end

        it "Content-Type が application/json であること" do
          post recap_movie_request_singing_badges_path, params: { year: year }, as: :json

          expect(response.content_type).to match(%r{application/json})
        end
      end

      context "Job enqueue（enqueueされる場合）" do
        include ActiveJob::TestHelper

        context "新規リクエストの場合（created_pending）" do
          before do
            allow(Singing::AchievementRecapMovieBuilder).to receive(:call).and_return(
              instance_double("Singing::AchievementRecapMovieBuilder::Result", empty?: false)
            )
            allow(Singing::AchievementRecapMovieSerializer).to receive(:new).and_return(
              instance_double("Singing::AchievementRecapMovieSerializer", as_json: { scenes: [] })
            )
          end

          it "Singing::GenerateRecapMovieJob が enqueue されること" do
            expect {
              post recap_movie_request_singing_badges_path, params: { year: year }, as: :json
            }.to have_enqueued_job(Singing::GenerateRecapMovieJob)
          end

          it "response に queued: true が含まれること" do
            post recap_movie_request_singing_badges_path, params: { year: year }, as: :json

            json = JSON.parse(response.body, symbolize_names: true)
            expect(json[:queued]).to be true
          end
        end

        context "失敗済みレコードをリセットした場合（reset_pending）" do
          let!(:failed_movie) { create(:singing_generated_recap_movie, :failed, customer: customer, year: year) }

          before do
            allow(Singing::AchievementRecapMovieBuilder).to receive(:call).and_return(
              instance_double("Singing::AchievementRecapMovieBuilder::Result", empty?: false)
            )
            allow(Singing::AchievementRecapMovieSerializer).to receive(:new).and_return(
              instance_double("Singing::AchievementRecapMovieSerializer", as_json: { scenes: [] })
            )
          end

          it "Singing::GenerateRecapMovieJob が enqueue されること" do
            expect {
              post recap_movie_request_singing_badges_path, params: { year: year }, as: :json
            }.to have_enqueued_job(Singing::GenerateRecapMovieJob)
          end

          it "response に queued: true が含まれること" do
            post recap_movie_request_singing_badges_path, params: { year: year }, as: :json

            json = JSON.parse(response.body, symbolize_names: true)
            expect(json[:queued]).to be true
          end
        end
      end

      context "Job enqueue（enqueueされない場合）" do
        include ActiveJob::TestHelper

        context "already_pending の場合" do
          let!(:existing_movie) { create(:singing_generated_recap_movie, customer: customer, year: year, status: :pending) }

          it "Job が enqueue されないこと" do
            expect {
              post recap_movie_request_singing_badges_path, params: { year: year }, as: :json
            }.not_to have_enqueued_job(Singing::GenerateRecapMovieJob)
          end

          it "response に queued: false が含まれること" do
            post recap_movie_request_singing_badges_path, params: { year: year }, as: :json

            json = JSON.parse(response.body, symbolize_names: true)
            expect(json[:queued]).to be false
          end
        end

        context "already_processing の場合" do
          let!(:existing_movie) { create(:singing_generated_recap_movie, customer: customer, year: year, status: :processing) }

          it "Job が enqueue されないこと" do
            expect {
              post recap_movie_request_singing_badges_path, params: { year: year }, as: :json
            }.not_to have_enqueued_job(Singing::GenerateRecapMovieJob)
          end

          it "response に queued: false が含まれること" do
            post recap_movie_request_singing_badges_path, params: { year: year }, as: :json

            json = JSON.parse(response.body, symbolize_names: true)
            expect(json[:queued]).to be false
          end
        end

        context "reused_completed の場合" do
          let!(:existing_movie) { create(:singing_generated_recap_movie, :completed, customer: customer, year: year) }

          it "Job が enqueue されないこと" do
            expect {
              post recap_movie_request_singing_badges_path, params: { year: year }, as: :json
            }.not_to have_enqueued_job(Singing::GenerateRecapMovieJob)
          end

          it "response に queued: false が含まれること" do
            post recap_movie_request_singing_badges_path, params: { year: year }, as: :json

            json = JSON.parse(response.body, symbolize_names: true)
            expect(json[:queued]).to be false
          end
        end

        context "empty_source の場合" do
          before do
            allow(Singing::AchievementRecapMovieBuilder).to receive(:call).and_return(
              instance_double("Singing::AchievementRecapMovieBuilder::Result", empty?: true)
            )
          end

          it "Job が enqueue されないこと" do
            expect {
              post recap_movie_request_singing_badges_path, params: { year: year }, as: :json
            }.not_to have_enqueued_job(Singing::GenerateRecapMovieJob)
          end

          it "response に queued: false が含まれること" do
            post recap_movie_request_singing_badges_path, params: { year: year }, as: :json

            json = JSON.parse(response.body, symbolize_names: true)
            expect(json[:queued]).to be false
          end
        end
      end
    end
  end

  # ── GET /singing/badges/recap_movie_status ────────────────────────────────

  describe "GET /singing/badges/recap_movie_status" do
    let(:year) { Time.current.year }

    context "未ログインの場合" do
      it "ログインページへリダイレクトまたは401になること" do
        get recap_movie_status_singing_badges_path, params: { year: year }, as: :json

        expect(response.status).to be_in([302, 401])
      end
    end

    context "ログイン済みの場合" do
      before { sign_in customer }

      it "200 を返すこと" do
        get recap_movie_status_singing_badges_path, params: { year: year }, as: :json

        expect(response).to have_http_status(:ok)
      end

      it "Content-Type が application/json であること" do
        get recap_movie_status_singing_badges_path, params: { year: year }, as: :json

        expect(response.content_type).to match(%r{application/json})
      end

      context "未作成の場合（not_requested）" do
        it "exists: false / status: not_requested を返すこと" do
          get recap_movie_status_singing_badges_path, params: { year: year }, as: :json

          json = JSON.parse(response.body, symbolize_names: true)
          expect(json[:exists]).to be false
          expect(json[:status]).to eq("not_requested")
          expect(json[:year]).to eq(year)
          expect(json[:movie]).to be_nil
          expect(json[:message]).to be_present
        end
      end

      context "pending 状態の場合" do
        let!(:movie) { create(:singing_generated_recap_movie, customer: customer, year: year, status: :pending) }

        it "exists: true / status: pending を返すこと" do
          get recap_movie_status_singing_badges_path, params: { year: year }, as: :json

          json = JSON.parse(response.body, symbolize_names: true)
          expect(json[:exists]).to be true
          expect(json[:status]).to eq("pending")
          expect(json[:movie][:id]).to eq(movie.id)
          expect(json[:movie][:reusable]).to be false
          expect(json[:movie][:video_url]).to be_nil
        end
      end

      context "processing 状態の場合" do
        let!(:movie) { create(:singing_generated_recap_movie, customer: customer, year: year, status: :processing) }

        it "exists: true / status: processing を返すこと" do
          get recap_movie_status_singing_badges_path, params: { year: year }, as: :json

          json = JSON.parse(response.body, symbolize_names: true)
          expect(json[:exists]).to be true
          expect(json[:status]).to eq("processing")
          expect(json[:movie][:id]).to eq(movie.id)
          expect(json[:movie][:reusable]).to be false
        end
      end

      context "completed かつ reusable な場合" do
        let!(:movie) { create(:singing_generated_recap_movie, :completed, customer: customer, year: year) }

        it "exists: true / status: completed / reusable: true を返すこと" do
          get recap_movie_status_singing_badges_path, params: { year: year }, as: :json

          json = JSON.parse(response.body, symbolize_names: true)
          expect(json[:exists]).to be true
          expect(json[:status]).to eq("completed")
          expect(json[:movie][:reusable]).to be true
          expect(json[:movie][:generated_at]).to be_present
        end
      end

      context "failed の場合" do
        let!(:movie) { create(:singing_generated_recap_movie, :failed, customer: customer, year: year) }

        it "exists: true / status: failed / error_message が含まれること" do
          get recap_movie_status_singing_badges_path, params: { year: year }, as: :json

          json = JSON.parse(response.body, symbolize_names: true)
          expect(json[:exists]).to be true
          expect(json[:status]).to eq("failed")
          expect(json[:movie][:error_message]).to be_present
          expect(json[:movie][:reusable]).to be false
        end
      end

      context "expired の場合" do
        let!(:movie) { create(:singing_generated_recap_movie, :expired, customer: customer, year: year) }

        it "exists: true / status: expired を返すこと" do
          get recap_movie_status_singing_badges_path, params: { year: year }, as: :json

          json = JSON.parse(response.body, symbolize_names: true)
          expect(json[:exists]).to be true
          expect(json[:status]).to eq("expired")
          expect(json[:movie][:reusable]).to be false
        end
      end

      context "レスポンス構造" do
        it "トップレベルキー exists / year / status / message / movie が揃っていること" do
          get recap_movie_status_singing_badges_path, params: { year: year }, as: :json

          json = JSON.parse(response.body, symbolize_names: true)
          expect(json.keys).to include(:exists, :year, :status, :message, :movie)
        end

        context "movie が存在する場合" do
          let!(:movie) { create(:singing_generated_recap_movie, customer: customer, year: year, status: :pending) }

          it "movie に必要なキーが揃っていること" do
            get recap_movie_status_singing_badges_path, params: { year: year }, as: :json

            json = JSON.parse(response.body, symbolize_names: true)
            expect(json[:movie].keys).to include(:id, :year, :status, :reusable, :video_url, :error_message, :generated_at, :expires_at)
          end
        end
      end

      context "セキュリティ: 他ユーザーの movie は見えないこと" do
        let!(:other_movie) { create(:singing_generated_recap_movie, :completed, customer: other_customer, year: year) }

        it "他ユーザーの movie が存在しても not_requested を返すこと" do
          get recap_movie_status_singing_badges_path, params: { year: year }, as: :json

          json = JSON.parse(response.body, symbolize_names: true)
          expect(json[:exists]).to be false
          expect(json[:status]).to eq("not_requested")
        end
      end

      context "不正な year パラメータ" do
        it "year=0 でも 500 にならないこと" do
          get recap_movie_status_singing_badges_path, params: { year: "0" }, as: :json

          expect(response.status).not_to eq(500)
        end

        it "year=abc でも 500 にならないこと" do
          get recap_movie_status_singing_badges_path, params: { year: "abc" }, as: :json

          expect(response.status).not_to eq(500)
        end

        it "year 未指定でも JSON が返ること" do
          get recap_movie_status_singing_badges_path, as: :json

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json["status"]).to be_present
        end
      end
    end
  end
end
