require "rails_helper"

RSpec.describe Singing::ReturnMotivationBuilder do
  include ActiveSupport::Testing::TimeHelpers

  describe ".call" do
    let(:customer) { create(:customer, domain_name: "singing") }
    let(:now) { Time.zone.local(2026, 6, 3, 12, 0, 0) }

    around do |example|
      travel_to(now) { example.run }
    end

    it "customer nilでは表示しない" do
      result = described_class.call(nil)

      expect(result).to be_a(described_class::ReturnMotivation)
      expect(result.visible).to eq(false)
    end

    it "診断なしでは最初の一歩として表示する" do
      result = described_class.call(customer)

      expect(result.visible).to eq(true)
      expect(result.title).to eq("おかえりなさい 🎵")
      expect(result.message).to include("また今日から音楽を楽しみましょう")
    end

    it "3日空きではおかえりメッセージを返す" do
      create(:singing_diagnosis, :completed, customer: customer, created_at: 3.days.ago)

      result = described_class.call(customer)

      expect(result.visible).to eq(true)
      expect(result.title).to eq("おかえりなさい 🎵")
      expect(result.message).to include("少し間が空いても大丈夫")
    end

    it "7日空きでは一歩だけのメッセージを返す" do
      create(:singing_diagnosis, :completed, customer: customer, created_at: 7.days.ago)

      result = described_class.call(customer)

      expect(result.visible).to eq(true)
      expect(result.title).to eq("あなたの音楽を待っています 🎤")
      expect(result.message).to include("まずは一歩だけ")
    end

    it "30日空きではいつでも帰ってきてくださいメッセージを返す" do
      create(:singing_diagnosis, :completed, customer: customer, created_at: 30.days.ago)

      result = described_class.call(customer)

      expect(result.visible).to eq(true)
      expect(result.title).to eq("また歌いたくなったら、")
      expect(result.message).to include("いつでも帰ってきてください")
    end

    it "最近活動ありでは表示しない" do
      create(:singing_diagnosis, :completed, customer: customer, created_at: 2.days.ago)

      result = described_class.call(customer)

      expect(result.visible).to eq(false)
    end

    it "CTA path は新規診断画面を返す" do
      result = described_class.call(customer)

      expect(result.cta_label).to eq("今日の診断をする")
      expect(result.cta_path).to eq(Rails.application.routes.url_helpers.new_singing_diagnosis_path)
    end
  end
end
