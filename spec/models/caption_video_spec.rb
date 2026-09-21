require "rails_helper"

RSpec.describe CaptionVideo, type: :model do
  describe "associations" do
    it "customerにbelongsすること" do
      expect(described_class.reflect_on_association(:customer).macro).to eq :belongs_to
    end

    it "video_captionsをdependent: :destroyでhas_manyすること" do
      reflection = described_class.reflect_on_association(:video_captions)
      expect(reflection.macro).to eq :has_many
      expect(reflection.options[:dependent]).to eq :destroy
    end

    it "紐づくvideo_captionsが削除と共に消えること" do
      caption_video = create(:caption_video)
      create(:video_caption, caption_video: caption_video)
      expect { caption_video.destroy }.to change(VideoCaption, :count).by(-1)
    end
  end

  describe "validations" do
    it "有効なfactoryはvalidであること" do
      expect(build(:caption_video)).to be_valid
    end

    it "titleが無いとinvalidであること" do
      caption_video = build(:caption_video, title: nil)
      expect(caption_video).not_to be_valid
      expect(caption_video.errors[:title]).to be_present
    end

    it "titleがTITLE_MAX_LENGTHを超えるとinvalidであること" do
      caption_video = build(:caption_video, title: "あ" * (described_class::TITLE_MAX_LENGTH + 1))
      expect(caption_video).not_to be_valid
      expect(caption_video.errors[:title]).to be_present
    end

    it "source_videoが未添付だとinvalidであること" do
      caption_video = build(:caption_video)
      caption_video.source_video = nil
      expect(caption_video).not_to be_valid
      expect(caption_video.errors[:source_video]).to be_present
    end

    it "source_videoのcontent_typeがmp4以外だとinvalidであること" do
      caption_video = build(:caption_video)
      caption_video.source_video.attach(
        io: StringIO.new("dummy"), filename: "sample.mov", content_type: "video/quicktime"
      )
      expect(caption_video).not_to be_valid
      expect(caption_video.errors[:source_video]).to be_present
    end

    it "source_videoが500MBを超えるとinvalidであること" do
      caption_video = build(:caption_video)
      allow(caption_video.source_video).to receive(:byte_size).and_return(described_class::MAX_SOURCE_VIDEO_BYTES + 1)
      expect(caption_video).not_to be_valid
      expect(caption_video.errors[:source_video]).to be_present
    end
  end

  describe "status enum" do
    it "文字列バッキングであること(整数の暗黙変換に依存しない)" do
      caption_video = create(:caption_video, status: "ready_for_edit")
      expect(described_class.connection.select_value(
        "SELECT status FROM caption_videos WHERE id = #{caption_video.id}"
      )).to eq("ready_for_edit")
    end
  end

  describe "#processing?" do
    it "extracting_audio/transcribing/renderingの間はtrueであること" do
      expect(build(:caption_video, status: "extracting_audio")).to be_processing
      expect(build(:caption_video, status: "transcribing")).to be_processing
      expect(build(:caption_video, status: "rendering")).to be_processing
    end

    it "uploaded/ready_for_edit/completed/failedではfalseであること" do
      expect(build(:caption_video, status: "uploaded")).not_to be_processing
      expect(build(:caption_video, status: "ready_for_edit")).not_to be_processing
      expect(build(:caption_video, status: "completed")).not_to be_processing
      expect(build(:caption_video, status: "failed")).not_to be_processing
    end
  end

  describe "#render_requestable?" do
    it "ready_for_editでテロップがあればtrueであること" do
      caption_video = create(:caption_video, :ready_for_edit)
      create(:video_caption, caption_video: caption_video)
      expect(caption_video.render_requestable?).to be true
    end

    it "テロップが無ければfalseであること" do
      caption_video = create(:caption_video, :ready_for_edit)
      expect(caption_video.render_requestable?).to be false
    end

    it "uploaded中はfalseであること" do
      caption_video = create(:caption_video, status: "uploaded")
      create(:video_caption, caption_video: caption_video)
      expect(caption_video.render_requestable?).to be false
    end
  end

  describe "#mark_failed!" do
    it "statusをfailedにしerror_messageを保存すること" do
      caption_video = create(:caption_video)
      caption_video.mark_failed!("失敗しました")
      expect(caption_video.reload.status).to eq("failed")
      expect(caption_video.error_message).to eq("失敗しました")
    end

    it "error_messageをERROR_MESSAGE_MAX_LENGTH以内にtruncateすること" do
      caption_video = create(:caption_video)
      caption_video.mark_failed!("E" * 1000)
      expect(caption_video.reload.error_message.length).to be <= described_class::ERROR_MESSAGE_MAX_LENGTH
    end
  end

  describe "#mark_completed!" do
    it "statusをcompletedにしprocessing_completed_atを設定すること" do
      caption_video = create(:caption_video, status: "rendering")
      caption_video.mark_completed!
      expect(caption_video.reload.status).to eq("completed")
      expect(caption_video.processing_completed_at).to be_present
    end
  end

  describe "他人のcaption_videoへアクセスできないこと(所有者スコープ)" do
    it "current_customer.caption_videos経由でしか取得できないこと" do
      owner = create(:customer)
      other  = create(:customer)
      caption_video = create(:caption_video, customer: owner)

      expect(other.caption_videos.find_by(id: caption_video.id)).to be_nil
      expect(owner.caption_videos.find_by(id: caption_video.id)).to eq(caption_video)
    end
  end
end
