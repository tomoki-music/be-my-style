require "rails_helper"

RSpec.describe CaptionVideos::RenderJob, type: :job do
  let(:customer) { create(:customer) }

  def build_video_with_caption(status: "ready_for_edit")
    video = create(:caption_video, customer: customer, status: status, width: 1280, height: 720, duration: 10.0)
    create(:video_caption, caption_video: video, start_time: 0.0, end_time: 2.0, text: "テロップ")
    video
  end

  def stub_renderer_success
    allow(CaptionVideos::AssSubtitleGenerator).to receive(:call).and_return("dummy ass content")
    allow(CaptionVideos::VideoRenderer).to receive(:new) do |input_path:, ass_path:, output_path:, **_opts|
      File.write(output_path, "DUMMY_MP4")
      instance_double(CaptionVideos::VideoRenderer, call: true)
    end
  end

  describe "#perform" do
    context "caption_videoが存在しない場合" do
      it "何もしない" do
        expect { described_class.perform_now(0) }.not_to raise_error
      end
    end

    context "テロップが無い場合" do
      it "何もしない" do
        video = create(:caption_video, customer: customer, status: "ready_for_edit")
        expect(CaptionVideos::VideoRenderer).not_to receive(:new)
        described_class.perform_now(video.id)
        expect(video.reload.status).to eq("ready_for_edit")
      end
    end

    context "renderingできないstatusの場合" do
      it "何もしない" do
        video = create(:caption_video, customer: customer, status: "transcribing")
        create(:video_caption, caption_video: video)
        expect(CaptionVideos::VideoRenderer).not_to receive(:new)
        described_class.perform_now(video.id)
      end
    end

    context "既にrendering中の場合(冪等性)" do
      it "二重実行しないこと" do
        video = build_video_with_caption(status: "rendering")
        expect(CaptionVideos::VideoRenderer).not_to receive(:new)
        described_class.perform_now(video.id)
      end
    end

    context "別の動画が既にrendering中の場合(グローバル同時実行数1)" do
      it "実行しないこと" do
        video = build_video_with_caption
        other = build_video_with_caption
        other.update!(status: "rendering")

        expect(CaptionVideos::VideoRenderer).not_to receive(:new)
        described_class.perform_now(video.id)
        expect(video.reload.status).to eq("ready_for_edit")
      end
    end

    context "正常系" do
      let(:video) { build_video_with_caption }

      before { stub_renderer_success }

      it "statusをcompletedにすること" do
        described_class.perform_now(video.id)
        expect(video.reload.status).to eq("completed")
      end

      it "rendered_videoを添付すること" do
        described_class.perform_now(video.id)
        expect(video.reload.rendered_video).to be_attached
      end

      it "processing_completed_atを設定すること" do
        described_class.perform_now(video.id)
        expect(video.reload.processing_completed_at).to be_present
      end

      it "AssSubtitleGeneratorへ動画の解像度を渡すこと" do
        described_class.perform_now(video.id)
        expect(CaptionVideos::AssSubtitleGenerator).to have_received(:call).with(anything, width: 1280, height: 720)
      end
    end

    context "MOVをアップロードした動画をレンダリングする場合" do
      def build_mov_video_with_caption(status: "ready_for_edit")
        video = create(:caption_video, :mov, customer: customer, status: status, width: 1280, height: 720, duration: 16.minutes.to_f)
        create(:video_caption, caption_video: video, start_time: 0.0, end_time: 2.0, text: "テロップ")
        video
      end

      let(:video) { build_mov_video_with_caption }

      before { stub_renderer_success }

      it "完成動画としてMP4が添付されること(content_typeはvideo/mp4)" do
        described_class.perform_now(video.id)
        video.reload
        expect(video.status).to eq("completed")
        expect(video.rendered_video).to be_attached
        expect(video.rendered_video.content_type).to eq("video/mp4")
      end

      it "拡張子.movのまま一時ファイルへ書き出し、VideoRendererへ渡すこと" do
        captured_input_path = nil
        allow(CaptionVideos::VideoRenderer).to receive(:new) do |input_path:, output_path:, **_opts|
          captured_input_path = input_path
          File.write(output_path, "DUMMY_MP4")
          instance_double(CaptionVideos::VideoRenderer, call: true)
        end

        described_class.perform_now(video.id)
        expect(captured_input_path).to end_with(".mov")
      end
    end

    context "縦向き動画(width<height)をレンダリングする場合" do
      it "AssSubtitleGeneratorへ縦向きの解像度をそのまま渡すこと(入れ替えないこと)" do
        video = create(:caption_video, customer: customer, status: "ready_for_edit", width: 1080, height: 1920, duration: 60.0)
        create(:video_caption, caption_video: video, start_time: 0.0, end_time: 2.0, text: "テロップ")
        stub_renderer_success

        described_class.perform_now(video.id)
        expect(CaptionVideos::AssSubtitleGenerator).to have_received(:call).with(anything, width: 1080, height: 1920)
      end
    end

    context "completedからの再生成の場合" do
      let(:video) { build_video_with_caption(status: "completed") }

      before { stub_renderer_success }

      it "再びcompletedになり、rendered_videoが置き換わること" do
        video.rendered_video.attach(io: StringIO.new("OLD"), filename: "old.mp4", content_type: "video/mp4")
        old_blob_id = video.rendered_video.blob.id

        described_class.perform_now(video.id)

        video.reload
        expect(video.status).to eq("completed")
        expect(video.rendered_video.blob.id).not_to eq(old_blob_id)
      end
    end

    context "レンダリングが失敗する場合" do
      let(:video) { build_video_with_caption }

      before do
        allow(CaptionVideos::AssSubtitleGenerator).to receive(:call).and_return("dummy ass content")
        allow(CaptionVideos::VideoRenderer).to receive(:new).and_raise(CaptionVideos::VideoRenderer::RenderError, "encode failed detail")
      end

      it "failedになり、ユーザー向けメッセージ(内部エラー詳細を含まない)を保存すること" do
        described_class.perform_now(video.id)
        video.reload
        expect(video.status).to eq("failed")
        expect(video.error_message).not_to include("encode failed detail")
      end

      it "rendered_videoが添付されないこと" do
        described_class.perform_now(video.id)
        expect(video.reload.rendered_video).not_to be_attached
      end
    end

    context "予期しない例外が発生する場合" do
      let(:video) { build_video_with_caption }

      before do
        allow(CaptionVideos::AssSubtitleGenerator).to receive(:call).and_raise(StandardError, "unexpected")
      end

      it "例外を外へ漏らさずfailedにすること" do
        expect { described_class.perform_now(video.id) }.not_to raise_error
        expect(video.reload.status).to eq("failed")
      end
    end
  end
end
