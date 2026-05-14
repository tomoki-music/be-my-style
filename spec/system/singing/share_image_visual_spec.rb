require "rails_helper"

RSpec.describe "Singing share image visual", type: :system, js: true do
  include Warden::Test::Helpers

  let(:year) { Time.current.year }
  let(:customer) { create(:customer, domain_name: "singing") }
  let(:long_song_title) do
    "Shareable Voice Screenshot Title With Extra Long Words And Mobile Layout Pressure #{year}"
  end

  before do
    customer.create_subscription!(status: "active", plan: plan)
    create_completed_diagnosis(
      created_at: Time.zone.local(year, 1, 10, 10, 0, 0),
      overall_score: 60,
      pitch_score: 50,
      rhythm_score: 58,
      expression_score: 55
    )
    create_completed_diagnosis(
      created_at: Time.zone.local(year, 10, 10, 10, 0, 0),
      overall_score: 78,
      pitch_score: 84,
      rhythm_score: 70,
      expression_score: 68
    )
    create(
      :singing_ai_challenge_progress,
      customer: customer,
      target_key: "pitch",
      challenge_month: Date.new(year, 8, 1),
      tried: true
    )
    login_as(customer, scope: :customer)
  end

  after do
    Warden.test_reset!
  end

  context "coreユーザー" do
    let(:plan) { "core" }

    it "375px幅でもカードが横にはみ出さず、長い曲名でもカード内に収まる" do
      resize_browser_to(375, 900)

      visit singing_share_image_path

      expect(page).to have_selector(".singing-share-image__card")
      expect(page.html).to include(long_song_title)
      expect(page.html).to include("最も挑戦したAIチャレンジ")

      save_screenshot(Rails.root.join("tmp/screenshots/singing_share_image_mobile.png").to_s)

      aggregate_failures do
        expect(card_layout).to include(
          "fitsViewport" => true,
          "childrenFitCardHorizontally" => true
        )
      end
    end

    it "1280px前後のPC幅でカードが中央表示される" do
      resize_browser_to(1280, 960)

      visit singing_share_image_path

      expect(page).to have_selector(".singing-share-image__card")
      expect(page.html).to include(long_song_title)
      save_screenshot(Rails.root.join("tmp/screenshots/singing_share_image_desktop.png").to_s)

      aggregate_failures do
        expect(card_layout.fetch("fitsViewport")).to eq(true)
        expect(card_layout.fetch("childrenFitCardHorizontally")).to eq(true)
        expect(card_layout.fetch("centerOffset").abs).to be <= 2
      end
    end
  end

  context "premiumユーザー" do
    let(:plan) { "premium" }

    it "シェアカードを表示できる" do
      resize_browser_to(1280, 960)

      visit singing_share_image_path

      expect(page).to have_selector(".singing-share-image__card", text: "#{year} YEAR IN VOICE")
      expect(page.html).to include(long_song_title)
    end
  end

  def create_completed_diagnosis(attributes)
    create(
      :singing_diagnosis,
      :completed,
      attributes.merge(
        customer: customer,
        song_title: long_song_title
      )
    )
  end

  def resize_browser_to(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
  end

  def card_layout
    page.evaluate_script(<<~JS)
      (function () {
        const card = document.querySelector(".singing-share-image__card");
        const cardRect = card.getBoundingClientRect();
        const tolerance = 1;
        const childrenFitCardHorizontally = Array.from(card.querySelectorAll("*")).every((node) => {
          const rect = node.getBoundingClientRect();
          return rect.left >= cardRect.left - tolerance &&
            rect.right <= cardRect.right + tolerance;
        });

        return {
          fitsViewport: cardRect.left >= -tolerance &&
            cardRect.right <= window.innerWidth + tolerance,
          childrenFitCardHorizontally: childrenFitCardHorizontally,
          centerOffset: (cardRect.left + (cardRect.width / 2)) - (window.innerWidth / 2)
        };
      })()
    JS
  end
end
