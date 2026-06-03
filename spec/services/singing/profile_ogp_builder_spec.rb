require "rails_helper"

RSpec.describe Singing::ProfileOgpBuilder do
  let(:customer) { create(:customer, domain_name: "singing", name: "Tomoki") }
  let(:base_url) { "https://example.com" }

  let(:timeline_with_personal_best) do
    Singing::MusicJourneyTimelineBuilder::MusicJourneyTimeline.new(
      timeline_items: [
        Singing::MusicJourneyTimelineBuilder::TimelineItem.new(
          type: :personal_best, title: "自己ベスト更新", description: "80点",
          occurred_at: 5.days.ago.to_date, icon: "⭐"
        ),
        Singing::MusicJourneyTimelineBuilder::TimelineItem.new(
          type: :first_diagnosis, title: "はじめて歌唱診断を実施", description: "65点でスタート",
          occurred_at: 30.days.ago.to_date, icon: "🎤"
        )
      ]
    )
  end

  let(:timeline_with_streak) do
    Singing::MusicJourneyTimelineBuilder::MusicJourneyTimeline.new(
      timeline_items: [
        Singing::MusicJourneyTimelineBuilder::TimelineItem.new(
          type: :streak_milestone, title: "7日継続達成", description: "7日間連続",
          occurred_at: 3.days.ago.to_date, icon: "🔥"
        ),
        Singing::MusicJourneyTimelineBuilder::TimelineItem.new(
          type: :first_diagnosis, title: "はじめて歌唱診断を実施", description: "65点でスタート",
          occurred_at: 14.days.ago.to_date, icon: "🎤"
        )
      ]
    )
  end

  let(:timeline_first_only) do
    Singing::MusicJourneyTimelineBuilder::MusicJourneyTimeline.new(
      timeline_items: [
        Singing::MusicJourneyTimelineBuilder::TimelineItem.new(
          type: :first_diagnosis, title: "はじめて歌唱診断を実施", description: "65点でスタート",
          occurred_at: 10.days.ago.to_date, icon: "🎤"
        )
      ]
    )
  end

  let(:empty_timeline) do
    Singing::MusicJourneyTimelineBuilder::MusicJourneyTimeline.new(timeline_items: [])
  end

  def call(user: customer, timeline: timeline_first_only)
    described_class.call(user, timeline, base_url: base_url)
  end

  describe "nil user の場合" do
    subject(:result) { described_class.call(nil, timeline_first_only, base_url: base_url) }

    it "fallback title が返る" do
      expect(result.title).to eq("🎵 Music Journey | BeMyStyle Singing")
    end

    it "fallback description が返る" do
      expect(result.description).to eq("歌を楽しみながら成長する音楽コミュニティです。")
    end

    it "image_asset_name が返る" do
      expect(result.image_asset_name).to eq("singing/ogp/music_journey_ogp.png")
    end

    it "url が nil になる" do
      expect(result.url).to be_nil
    end
  end

  describe "#title" do
    context "display_name あり" do
      it "名前が含まれる title が返る" do
        expect(call.title).to eq("🎵 TomokiのMusic Journey | BeMyStyle Singing")
      end
    end

    context "display_name なし（name が nil）" do
      let(:nameless_user) { double("Customer", id: 999, name: nil) }

      it "名前なし title が返る" do
        result = described_class.call(nameless_user, timeline_first_only, base_url: base_url)
        expect(result.title).to eq("🎵 Music Journey | BeMyStyle Singing")
      end
    end
  end

  describe "#description" do
    context "personal_best あり" do
      it "自己ベスト文言が返る" do
        result = call(timeline: timeline_with_personal_best)
        expect(result.description).to eq("自己ベストを更新しながら、自分らしい歌を育てています。")
      end
    end

    context "streak_milestone あり（personal_best なし）" do
      it "継続文言が返る" do
        result = call(timeline: timeline_with_streak)
        expect(result.description).to eq("コツコツ続けながら、自分らしい歌を育てています。")
      end
    end

    context "first_diagnosis のみ" do
      it "初診断文言が返る" do
        result = call(timeline: timeline_first_only)
        expect(result.description).to eq("ここから音楽の旅をはじめました。")
      end
    end

    context "timeline なし（空）" do
      it "デフォルト文言が返る" do
        result = call(timeline: empty_timeline)
        expect(result.description).to eq("歌を楽しみながら成長する音楽コミュニティです。")
      end
    end

    context "timeline が nil" do
      it "デフォルト文言が返る" do
        result = described_class.call(customer, nil, base_url: base_url)
        expect(result.description).to eq("歌を楽しみながら成長する音楽コミュニティです。")
      end
    end
  end

  describe "#image_asset_name" do
    it "music_journey_ogp.png を返す" do
      expect(call.image_asset_name).to eq("singing/ogp/music_journey_ogp.png")
    end

    context "nil user の場合" do
      it "同じ画像パスを返す" do
        result = described_class.call(nil, timeline_first_only, base_url: base_url)
        expect(result.image_asset_name).to eq("singing/ogp/music_journey_ogp.png")
      end
    end
  end

  describe "#url" do
    it "プロフィール URL が返る" do
      expect(call.url).to eq("https://example.com/singing/users/#{customer.id}")
    end
  end
end
