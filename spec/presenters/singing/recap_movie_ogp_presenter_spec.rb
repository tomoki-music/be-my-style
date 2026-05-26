require 'rails_helper'

RSpec.describe Singing::RecapMovieOgpPresenter do
  let(:customer)    { FactoryBot.build_stubbed(:customer, name: "テストユーザー") }
  let(:recap_movie) { FactoryBot.build_stubbed(:singing_generated_recap_movie, year: 2025, customer: customer) }
  let(:presenter)   { described_class.new(recap_movie, customer) }

  describe "#title" do
    it "ユーザー名と年を含むタイトルを返すこと" do
      expect(presenter.title).to eq("テストユーザーさんの 2025 Singing Recap | BeMyStyle")
    end
  end

  describe "#description" do
    it "年を含む説明文を返すこと" do
      expect(presenter.description).to include("2025年")
      expect(presenter.description).to include("BeMyStyle")
    end
  end

  describe "#twitter_card" do
    it "summary_large_image を返すこと" do
      expect(presenter.twitter_card).to eq("summary_large_image")
    end
  end

  describe "#image_asset_name" do
    it "文字列を返すこと" do
      expect(presenter.image_asset_name).to be_a(String)
      expect(presenter.image_asset_name).to be_present
    end
  end
end
