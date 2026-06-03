require "rails_helper"

RSpec.describe Singing::JourneyShareBuilder do
  let(:customer)      { create(:customer, domain_name: "singing", name: "テストユーザー") }
  let(:other_customer) { create(:customer, domain_name: "singing", name: "他のユーザー") }
  let(:base_url)      { "https://example.com" }

  let(:timeline_with_items) do
    Singing::MusicJourneyTimelineBuilder::MusicJourneyTimeline.new(
      timeline_items: [
        Singing::MusicJourneyTimelineBuilder::TimelineItem.new(
          type:        :first_diagnosis,
          title:       "はじめて歌唱診断を実施",
          description: "65点でスタート",
          occurred_at: 30.days.ago.to_date,
          icon:        "🎤"
        )
      ]
    )
  end

  let(:timeline_with_personal_best) do
    Singing::MusicJourneyTimelineBuilder::MusicJourneyTimeline.new(
      timeline_items: [
        Singing::MusicJourneyTimelineBuilder::TimelineItem.new(
          type:        :personal_best,
          title:       "自己ベスト更新",
          description: "80点",
          occurred_at: 5.days.ago.to_date,
          icon:        "⭐"
        ),
        Singing::MusicJourneyTimelineBuilder::TimelineItem.new(
          type:        :first_diagnosis,
          title:       "はじめて歌唱診断を実施",
          description: "65点でスタート",
          occurred_at: 30.days.ago.to_date,
          icon:        "🎤"
        )
      ]
    )
  end

  let(:timeline_with_streak) do
    Singing::MusicJourneyTimelineBuilder::MusicJourneyTimeline.new(
      timeline_items: [
        Singing::MusicJourneyTimelineBuilder::TimelineItem.new(
          type:        :streak_milestone,
          title:       "7日継続達成",
          description: "7日間連続で診断を続けました",
          occurred_at: 3.days.ago.to_date,
          icon:        "🔥"
        ),
        Singing::MusicJourneyTimelineBuilder::TimelineItem.new(
          type:        :first_diagnosis,
          title:       "はじめて歌唱診断を実施",
          description: "65点でスタート",
          occurred_at: 14.days.ago.to_date,
          icon:        "🎤"
        )
      ]
    )
  end

  let(:empty_timeline) do
    Singing::MusicJourneyTimelineBuilder::MusicJourneyTimeline.new(timeline_items: [])
  end

  def call(current_customer: customer, profile_user: customer, timeline: timeline_with_items)
    described_class.call(current_customer, profile_user, timeline, base_url: base_url)
  end

  describe "#visible" do
    context "current_customer が nil の場合" do
      it "visible が false になる" do
        result = call(current_customer: nil)
        expect(result.visible).to be false
      end
    end

    context "profile_user が nil の場合" do
      it "visible が false になる" do
        result = described_class.call(customer, nil, timeline_with_items, base_url: base_url)
        expect(result.visible).to be false
      end
    end

    context "本人以外が閲覧する場合" do
      it "visible が false になる" do
        result = call(current_customer: other_customer, profile_user: customer)
        expect(result.visible).to be false
      end
    end

    context "timeline_items が空の場合" do
      it "visible が false になる" do
        result = call(timeline: empty_timeline)
        expect(result.visible).to be false
      end
    end

    context "timeline が nil の場合" do
      it "visible が false になる" do
        result = described_class.call(customer, customer, nil, base_url: base_url)
        expect(result.visible).to be false
      end
    end

    context "本人かつ timeline_items がある場合" do
      it "visible が true になる" do
        result = call
        expect(result.visible).to be true
      end
    end
  end

  describe "#share_text" do
    context "visible が false の場合" do
      it "share_text が nil になる" do
        result = call(current_customer: nil)
        expect(result.share_text).to be_nil
      end
    end

    context "自己ベストあり" do
      it "「自己ベストを更新しながら」が含まれる" do
        result = call(timeline: timeline_with_personal_best)
        expect(result.share_text).to include("自己ベストを更新しながら")
      end
    end

    context "継続記録あり（personal_best なし）" do
      it "「コツコツ続けながら」が含まれる" do
        result = call(timeline: timeline_with_streak)
        expect(result.share_text).to include("コツコツ続けながら")
      end
    end

    context "初診断のみ" do
      it "「ここから音楽の旅をはじめました」が含まれる" do
        result = call(timeline: timeline_with_items)
        expect(result.share_text).to include("ここから音楽の旅をはじめました")
      end
    end

    it "BeMyStyle への言及が含まれる" do
      result = call
      expect(result.share_text).to include("BeMyStyle Singing")
    end
  end

  describe "#x_share_url" do
    context "visible が false の場合" do
      it "x_share_url が nil になる" do
        result = call(current_customer: nil)
        expect(result.x_share_url).to be_nil
      end
    end

    context "visible が true の場合" do
      it "x.com の intent URL が返る" do
        result = call
        expect(result.x_share_url).to start_with("https://x.com/intent/tweet?text=")
      end

      it "URL にプロフィール URL がエンコードされて含まれる" do
        result = call
        expected_profile = CGI.escape("https://example.com/singing/users/#{customer.id}")
        expect(result.x_share_url).to include(expected_profile)
      end
    end
  end

  describe "#share_url" do
    context "visible が true の場合" do
      it "プロフィール URL が返る" do
        result = call
        expect(result.share_url).to eq("https://example.com/singing/users/#{customer.id}")
      end
    end
  end

  describe "#copy_text" do
    context "visible が true の場合" do
      it "プロフィール URL が返る" do
        result = call
        expect(result.copy_text).to eq("https://example.com/singing/users/#{customer.id}")
      end
    end
  end

  describe "#share_title" do
    context "visible が true の場合" do
      it "タイトル文言が返る" do
        result = call
        expect(result.share_title).to eq("あなたの音楽の歩みをシェアしよう")
      end
    end
  end
end
