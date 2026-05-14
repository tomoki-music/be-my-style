require "rails_helper"

RSpec.describe Singing::ShareTextBuilder, type: :service do
  let(:customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let(:other_customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let(:reference_time) { Time.zone.parse("2026-12-20 12:00:00") }

  describe ".yearly_growth_report" do
    it "coreユーザーにはcurrent_customerの年間成長だけを使ったSNS投稿文を返すこと" do
      customer.create_subscription!(status: "active", plan: "core")
      create_completed_diagnosis(customer, "Current Song", "2026-01-10", pitch_score: 50)
      create_completed_diagnosis(customer, "Current Song", "2026-11-10", pitch_score: 82)
      create_completed_diagnosis(other_customer, "Other Song", "2026-11-10", pitch_score: 99)

      text = described_class.yearly_growth_report(customer, reference_time: reference_time)

      expect(text).to eq("2026年は診断2回！音程が32点成長しました🎤 #BeMyStyleSinging")
      expect(text).not_to include("Other Song")
      expect(text).not_to include("99")
    end

    it "premiumユーザーには詳細な年間成長SNS投稿文を返すこと" do
      customer.create_subscription!(status: "active", plan: "premium")
      create_completed_diagnosis(customer, "Premium Song", "2026-01-10", pitch_score: 50)
      create_completed_diagnosis(customer, "Premium Song", "2026-11-10", pitch_score: 68)

      text = described_class.yearly_growth_report(customer, reference_time: reference_time)

      expect(text).to include("2026年は診断2回")
      expect(text).to include("音程が18点成長")
      expect(text).to include("#BeMyStyleSinging")
    end

    it "freeユーザーには診断回数や成長量を含めない汎用投稿文を返すこと" do
      create_completed_diagnosis(customer, "Free Song", "2026-01-10", pitch_score: 50)
      create_completed_diagnosis(customer, "Free Song", "2026-11-10", pitch_score: 82)

      text = described_class.yearly_growth_report(customer, reference_time: reference_time)

      expect(text).to eq("BeMyStyleで歌声診断をしました🎤 #BeMyStyleSinging")
      expect(text).not_to include("診断2回")
      expect(text).not_to include("32点")
      expect(text).not_to include("Free Song")
    end

    it "lightユーザーには診断回数や成長量を含めない汎用投稿文を返すこと" do
      customer.create_subscription!(status: "active", plan: "light")
      create_completed_diagnosis(customer, "Light Song", "2026-01-10", pitch_score: 50)
      create_completed_diagnosis(customer, "Light Song", "2026-11-10", pitch_score: 82)

      text = described_class.yearly_growth_report(customer, reference_time: reference_time)

      expect(text).to eq("BeMyStyleで歌声診断をしました🎤 #BeMyStyleSinging")
      expect(text).not_to include("診断2回")
      expect(text).not_to include("32点")
      expect(text).not_to include("Light Song")
    end
  end

  def create_completed_diagnosis(owner, song_title, created_on, pitch_score:)
    FactoryBot.create(
      :singing_diagnosis,
      :completed,
      customer: owner,
      song_title: song_title,
      created_at: Time.zone.parse("#{created_on} 10:00:00"),
      overall_score: 60,
      pitch_score: pitch_score,
      rhythm_score: 58,
      expression_score: 55
    )
  end
end
