require "rails_helper"

RSpec.describe Singing::RecapMovieRequestService, type: :service do
  let(:customer) { create(:customer, domain_name: "singing") }
  let(:year)     { 2025 }

  subject(:result) { described_class.call(customer, year: year) }

  def stub_builder_empty
    allow(Singing::AchievementRecapMovieBuilder).to receive(:call)
      .with(customer, year: year)
      .and_return(instance_double(Singing::AchievementRecapMovieBuilder::Result, empty?: true))
  end

  def stub_builder_with_data
    scenes = []
    builder_result = instance_double(
      Singing::AchievementRecapMovieBuilder::Result,
      empty?:         false,
      year:           year,
      title:          "2025年の軌跡",
      subtitle:       "3件の Achievement",
      total_duration: 25,
      scenes:         scenes
    )
    allow(Singing::AchievementRecapMovieBuilder).to receive(:call)
      .with(customer, year: year)
      .and_return(builder_result)
    allow_any_instance_of(Singing::AchievementRecapMovieSerializer).to receive(:as_json)
      .and_return({ year: year, title: "2025年の軌跡", scenes: [] })
  end

  # --- reusable な completed を再利用 ---
  context "reusable な completed レコードがある場合" do
    let!(:movie) do
      create(:singing_generated_recap_movie, :completed, customer: customer, year: year,
             expires_at: 7.days.from_now)
    end

    it "status が :reused_completed になる" do
      expect(result.status).to eq(:reused_completed)
    end

    it "movie が既存レコードを指す" do
      expect(result.movie).to eq(movie)
    end

    it "reused が true" do
      expect(result.reused).to be true
    end

    it "created が false" do
      expect(result.created).to be false
    end

    it "Builder を呼ばない" do
      expect(Singing::AchievementRecapMovieBuilder).not_to receive(:call)
      result
    end
  end

  # --- pending を再利用 ---
  context "pending レコードがある場合" do
    let!(:movie) do
      create(:singing_generated_recap_movie, customer: customer, year: year, status: :pending)
    end

    it "status が :already_pending になる" do
      expect(result.status).to eq(:already_pending)
    end

    it "movie が既存レコードを指す" do
      expect(result.movie).to eq(movie)
    end

    it "Builder を呼ばない" do
      expect(Singing::AchievementRecapMovieBuilder).not_to receive(:call)
      result
    end
  end

  # --- processing を再利用 ---
  context "processing レコードがある場合" do
    let!(:movie) do
      create(:singing_generated_recap_movie, :processing, customer: customer, year: year)
    end

    it "status が :already_processing になる" do
      expect(result.status).to eq(:already_processing)
    end

    it "movie が既存レコードを指す" do
      expect(result.movie).to eq(movie)
    end

    it "Builder を呼ばない" do
      expect(Singing::AchievementRecapMovieBuilder).not_to receive(:call)
      result
    end
  end

  # --- failed を pending にリセット（Achievement データあり）---
  context "failed レコードがある場合（Achievement データあり）" do
    let!(:movie) do
      create(:singing_generated_recap_movie, :failed, customer: customer, year: year)
    end

    before { stub_builder_with_data }

    it "status が :reset_pending になる" do
      expect(result.status).to eq(:reset_pending)
    end

    it "movie の status が pending に更新される" do
      result
      expect(movie.reload.status).to eq("pending")
    end

    it "error_message がクリアされる" do
      result
      expect(movie.reload.error_message).to be_nil
    end

    it "source_json が保存される" do
      result
      expect(movie.reload.source_json).to be_present
    end
  end

  # --- failed を pending にリセット（Achievement データなし）---
  context "failed レコードがあり、Achievement データが空の場合" do
    let!(:movie) do
      create(:singing_generated_recap_movie, :failed, customer: customer, year: year)
    end

    before { stub_builder_empty }

    it "status が :reset_pending になること（source_json なしでも進む）" do
      expect(result.status).to eq(:reset_pending)
    end

    it "movie の status が pending に更新される" do
      result
      expect(movie.reload.status).to eq("pending")
    end

    it "source_json が nil になる" do
      result
      expect(movie.reload.source_json).to be_nil
    end
  end

  # --- expired を pending にリセット ---
  context "expired レコードがある場合" do
    let!(:movie) do
      create(:singing_generated_recap_movie, :expired, customer: customer, year: year)
    end

    before { stub_builder_with_data }

    it "status が :reset_pending になる" do
      expect(result.status).to eq(:reset_pending)
    end

    it "movie の status が pending に更新される" do
      result
      expect(movie.reload.status).to eq("pending")
    end
  end

  # --- expires_at が過去の completed を pending にリセット ---
  context "completed だが expires_at が過去のレコードがある場合" do
    let!(:movie) do
      create(:singing_generated_recap_movie, :completed, customer: customer, year: year,
             expires_at: 1.second.ago)
    end

    before { stub_builder_with_data }

    it "status が :reset_pending になる" do
      expect(result.status).to eq(:reset_pending)
    end

    it "movie の status が pending に更新される" do
      result
      expect(movie.reload.status).to eq("pending")
    end
  end

  # --- 新規 pending 作成（Achievement データあり）---
  context "レコードが存在しない場合（Achievement データあり）" do
    before { stub_builder_with_data }

    it "status が :created_pending になる" do
      expect(result.status).to eq(:created_pending)
    end

    it "新しい SingingGeneratedRecapMovie が作成される" do
      expect { result }.to change(SingingGeneratedRecapMovie, :count).by(1)
    end

    it "created が true" do
      expect(result.created).to be true
    end

    it "movie の status が pending" do
      expect(result.movie.status).to eq("pending")
    end

    it "source_json が保存される" do
      expect(result.movie.source_json).to be_present
    end

    it "movie が同 customer + year に紐づく" do
      m = result.movie
      expect(m.customer).to eq(customer)
      expect(m.year).to eq(year)
    end
  end

  # --- 新規 pending 作成（Achievement データなし）---
  context "レコードが存在せず Achievement データも空の場合" do
    before { stub_builder_empty }

    it "status が :created_pending になること（source_json なしでも作成する）" do
      expect(result.status).to eq(:created_pending)
    end

    it "新しい SingingGeneratedRecapMovie が作成される" do
      expect { result }.to change(SingingGeneratedRecapMovie, :count).by(1)
    end

    it "movie の status が pending" do
      expect(result.movie.status).to eq("pending")
    end

    it "source_json が nil" do
      expect(result.movie.source_json).to be_nil
    end
  end

  # --- source_json の内容確認 ---
  context "source_json の保存内容" do
    before { stub_builder_with_data }

    it "year キーが含まれる" do
      movie = result.movie
      expect(movie.source_json["year"]).to eq(year)
    end

    it "title キーが含まれる" do
      movie = result.movie
      expect(movie.source_json["title"]).to eq("2025年の軌跡")
    end
  end
end
