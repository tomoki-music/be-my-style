require "rails_helper"

RSpec.describe "Singing diagnosis result value UI", type: :system, js: true do
  include Warden::Test::Helpers

  let(:customer) { create(:customer, domain_name: "singing") }

  after do
    Warden.test_reset!
  end

  context "premiumユーザー・vocal診断・AIコメント成功・前回比較あり" do
    before do
      customer.create_subscription!(status: "active", plan: "premium")
      create(
        :singing_diagnosis,
        :completed,
        customer: customer,
        performance_type: :vocal,
        created_at: 3.days.ago
      )
      @diagnosis = create(
        :singing_diagnosis,
        :completed,
        customer: customer,
        performance_type: :vocal,
        song_title: "テストソング",
        overall_score: 82,
        ai_comment_status: :ai_comment_completed,
        ai_comment: "音程が安定していて、サビの伸びやかさが魅力的です。次はリズムの入りを意識してみましょう。" * 3,
        ai_commented_at: Time.current,
        next_mission_title: "リズムキープ強化",
        next_mission_body: "メトロノームに合わせて発声練習をしてみましょう。"
      )
      login_as(customer, scope: :customer)
    end

    it "AIコーチのフィードバックが詳細スコアより先に表示され、表示順どおりにセクションが並ぶこと" do
      use_desktop_viewport(width: 1280, height: 1200)
      visit singing_diagnosis_path(@diagnosis)

      expect(page).to have_content("あなたの歌声の魅力と、次に伸ばすポイント")
      expect(page).to have_content("AIコーチからのフィードバック")
      expect(page).to have_content("今日からできる練習")
      expect(page).to have_content("前回からの成長")
      expect(page).to have_selector(".singing-diagnosis__score-details")
      expect(page).to have_selector(".singing-diagnosis__radar-chart")

      value_summary_top = page.evaluate_script("document.querySelector('.singing-diagnosis__value-summary').getBoundingClientRect().top")
      score_details_top = page.evaluate_script("document.querySelector('.singing-diagnosis__score-details').getBoundingClientRect().top")
      expect(value_summary_top).to be < score_details_top

      FileUtils.mkdir_p(Rails.root.join("tmp/screenshots"))
      save_screenshot(Rails.root.join("tmp/screenshots/diagnosis_result_vocal_desktop_1280.png").to_s)
    end

    it "1600px幅でも主要カードが崩れず表示されること" do
      visit singing_diagnosis_path(@diagnosis)
      use_desktop_viewport(width: 1600, height: 1200)

      expect(page).to have_content("AIコーチからのフィードバック")
      FileUtils.mkdir_p(Rails.root.join("tmp/screenshots"))
      save_screenshot(Rails.root.join("tmp/screenshots/diagnosis_result_vocal_desktop_1600.png").to_s)
    end

    it "768px幅(タブレット)でも診断結果コンテンツ領域に横スクロールが発生しないこと" do
      # NOTE: グローバルナビゲーション(.singing-nav)は768px帯で既知の横あふれがあり、
      # 今回の診断結果画面の再構成とは無関係(対象外)のため、
      # ここでは診断結果コンテンツ本体(.singing-diagnosis)だけを検証する。
      visit singing_diagnosis_path(@diagnosis)
      page.driver.browser.execute_cdp(
        "Emulation.setDeviceMetricsOverride",
        width: 768, height: 1400, deviceScaleFactor: 1, mobile: true
      )

      expect(page).to have_content("AIコーチからのフィードバック")
      overflow = page.evaluate_script(<<~JS)
        (function() {
          const vw = document.documentElement.clientWidth;
          const root = document.querySelector('.singing-diagnosis');
          const offenders = Array.from(root.querySelectorAll('*')).filter((el) => {
            return el.getBoundingClientRect().right > vw + 1;
          });
          return offenders.length;
        })()
      JS
      expect(overflow).to eq(0)

      FileUtils.mkdir_p(Rails.root.join("tmp/screenshots"))
      save_screenshot(Rails.root.join("tmp/screenshots/diagnosis_result_vocal_tablet_768.png").to_s)
    end

    it "375px幅でも横スクロールが発生せず、CTAが画面内に収まること" do
      visit singing_diagnosis_path(@diagnosis)
      use_mobile_viewport(width: 375, height: 1600)

      expect(page).to have_content("AIコーチからのフィードバック")
      scroll_width = page.evaluate_script("document.documentElement.scrollWidth")
      client_width = page.evaluate_script("document.documentElement.clientWidth")
      expect(scroll_width).to be <= client_width

      cta_rect = page.evaluate_script(<<~JS)
        (function() {
          const el = document.querySelector(".singing-diagnosis__next-action-cta .btn");
          const rect = el.getBoundingClientRect();
          return { right: rect.right, viewportWidth: document.documentElement.clientWidth };
        })()
      JS
      expect(cta_rect["right"]).to be <= cta_rect["viewportWidth"] + 1

      FileUtils.mkdir_p(Rails.root.join("tmp/screenshots"))
      save_screenshot(Rails.root.join("tmp/screenshots/diagnosis_result_vocal_mobile_375.png").to_s)
    end
  end

  context "guitar診断(ボーカル以外)" do
    before do
      customer.create_subscription!(status: "active", plan: "core")
      @diagnosis = create(
        :singing_diagnosis,
        :completed,
        customer: customer,
        performance_type: :guitar,
        song_title: "ギター練習曲"
      )
      login_as(customer, scope: :customer)
    end

    it "メインコピーに「演奏」を使い、詳細スコアまで正常に表示されること" do
      use_desktop_viewport(width: 1280, height: 1200)
      visit singing_diagnosis_path(@diagnosis)

      expect(page).to have_content("あなたの演奏の魅力と、次に伸ばすポイント")
      expect(page).to have_no_content("あなたの歌声")
      expect(page).to have_selector(".singing-diagnosis__score-details")

      FileUtils.mkdir_p(Rails.root.join("tmp/screenshots"))
      save_screenshot(Rails.root.join("tmp/screenshots/diagnosis_result_guitar_desktop_1280.png").to_s)
    end
  end

  context "初回診断(前回比較なし)" do
    before do
      customer.create_subscription!(status: "active", plan: "free")
      @diagnosis = create(:singing_diagnosis, :completed, customer: customer, performance_type: :vocal)
      login_as(customer, scope: :customer)
    end

    it "成長のスタート地点を示す空状態が表示され、AIコメントは空カードにせずアップグレード導線を出すこと" do
      use_desktop_viewport(width: 1280, height: 1200)
      visit singing_diagnosis_path(@diagnosis)

      expect(page).to have_content("今回の歌声を振り返り、次の成長へ")
      expect(page).to have_no_content("あなたの歌声の魅力と、次に伸ばすポイント")
      expect(page).to have_content("今回の結果が、これからの成長のスタート地点です。")
      expect(page).to have_content("AIコーチからのフィードバック")
      expect(page).to have_content("Premiumで解放する")

      FileUtils.mkdir_p(Rails.root.join("tmp/screenshots"))
      save_screenshot(Rails.root.join("tmp/screenshots/diagnosis_result_first_time_desktop_1280.png").to_s)
    end
  end

  context "AIコメント生成中" do
    before do
      customer.create_subscription!(status: "active", plan: "premium")
      @diagnosis = create(
        :singing_diagnosis,
        :completed,
        customer: customer,
        performance_type: :vocal,
        ai_comment_status: :ai_comment_processing
      )
      login_as(customer, scope: :customer)
    end

    it "生成中メッセージが表示され、画面全体は正常にレンダリングされること" do
      use_desktop_viewport(width: 1280, height: 1200)
      visit singing_diagnosis_path(@diagnosis)

      expect(page).to have_content("AIコーチが診断結果を整理しています")
      expect(page).to have_selector(".singing-diagnosis__score-details")
    end
  end
end
