require "rails_helper"

RSpec.describe VideoCaption, type: :model do
  let(:caption_video) { create(:caption_video, duration: 60.0) }

  describe "associations" do
    it "caption_videoにbelongsすること" do
      expect(described_class.reflect_on_association(:caption_video).macro).to eq :belongs_to
    end
  end

  describe "validations" do
    it "有効なfactoryはvalidであること" do
      expect(build(:video_caption, caption_video: caption_video)).to be_valid
    end

    it "textが空だとinvalidであること" do
      caption = build(:video_caption, caption_video: caption_video, text: "")
      expect(caption).not_to be_valid
      expect(caption.errors[:text]).to be_present
    end

    it "start_timeが負の値だとinvalidであること" do
      caption = build(:video_caption, caption_video: caption_video, start_time: -1.0)
      expect(caption).not_to be_valid
      expect(caption.errors[:start_time]).to be_present
    end

    it "end_timeがstart_time以下だとinvalidであること" do
      caption = build(:video_caption, caption_video: caption_video, start_time: 5.0, end_time: 5.0)
      expect(caption).not_to be_valid
      expect(caption.errors[:end_time]).to be_present
    end

    it "end_timeが動画の長さを超えるとinvalidであること" do
      caption = build(:video_caption, caption_video: caption_video, start_time: 1.0, end_time: 61.0)
      expect(caption).not_to be_valid
      expect(caption.errors[:end_time]).to be_present
    end

    it "caption_typeが不正な値だとRailsのenumによりArgumentErrorになること" do
      caption = build(:video_caption, caption_video: caption_video)
      expect { caption.caption_type = "unknown_type" }.to raise_error(ArgumentError)
    end

    it "positionが許可リスト外だとinvalidであること" do
      caption = build(:video_caption, caption_video: caption_video, position: "top_left")
      expect(caption).not_to be_valid
      expect(caption.errors[:position]).to be_present
    end
  end

  describe "#duration" do
    it "end_time - start_timeを返すこと" do
      caption = build(:video_caption, caption_video: caption_video, start_time: 1.5, end_time: 4.0)
      expect(caption.duration).to eq(2.5)
    end
  end

  describe "start_time/end_timeの精度" do
    it "ミリ秒単位の小数を保持できること" do
      caption = create(:video_caption, caption_video: caption_video, start_time: 1.234, end_time: 2.345)
      expect(caption.reload.start_time.to_f).to eq(1.234)
      expect(caption.reload.end_time.to_f).to eq(2.345)
    end
  end
end
