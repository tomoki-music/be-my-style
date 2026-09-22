require "rails_helper"

RSpec.describe CaptionVideos::ExtractAudioJob, type: :job do
  let(:customer) { create(:customer) }
  let(:probe_result) do
    CaptionVideos::VideoProbe::Result.new(
      duration: 30.0, width: 1280, height: 720, has_audio_stream: true,
      format_name: "mov,mp4,m4a,3gp,3g2,mj2"
    )
  end

  def stub_probe(result: probe_result)
    allow(CaptionVideos::VideoProbe).to receive(:new).and_return(instance_double(CaptionVideos::VideoProbe, call: result))
  end

  def stub_audio_extractor
    allow(CaptionVideos::AudioExtractor).to receive(:new) do |input_path:, output_path:, **_opts|
      File.write(output_path, "DUMMY_AUDIO")
      instance_double(CaptionVideos::AudioExtractor, call: true)
    end
  end

  describe "#perform" do
    context "caption_videoが存在しない場合" do
      it "何もしない" do
        expect { described_class.perform_now(0) }.not_to raise_error
      end
    end

    context "statusがuploadedでない場合(冪等性)" do
      it "何もしない" do
        video = create(:caption_video, customer: customer, status: "ready_for_edit")
        expect(CaptionVideos::VideoProbe).not_to receive(:new)
        described_class.perform_now(video.id)
        expect(video.reload.status).to eq("ready_for_edit")
      end
    end

    context "正常系" do
      let(:video) { create(:caption_video, customer: customer, status: "uploaded") }

      before do
        stub_probe
        stub_audio_extractor
        allow(CaptionVideos::TranscribeJob).to receive(:perform_later)
      end

      it "動画メタデータを保存すること" do
        described_class.perform_now(video.id)
        video.reload
        expect(video.duration).to eq(30.0)
        expect(video.width).to eq(1280)
        expect(video.height).to eq(720)
        expect(video.aspect_ratio).to eq("16:9")
      end

      it "statusをtranscribingにしaudio_extracted_atを設定すること" do
        described_class.perform_now(video.id)
        video.reload
        expect(video.status).to eq("transcribing")
        expect(video.audio_extracted_at).to be_present
      end

      it "extracted_audioを添付すること" do
        described_class.perform_now(video.id)
        expect(video.reload.extracted_audio).to be_attached
      end

      it "TranscribeJobをenqueueすること" do
        described_class.perform_now(video.id)
        expect(CaptionVideos::TranscribeJob).to have_received(:perform_later).with(video.id)
      end
    end

    context "動画が30分を超える場合" do
      let(:video) { create(:caption_video, customer: customer, status: "uploaded") }

      before do
        stub_probe(result: CaptionVideos::VideoProbe::Result.new(
          duration: 1900.0, width: 1280, height: 720, has_audio_stream: true, format_name: "mp4"
        ))
      end

      it "failedになり、時間超過のメッセージを保存すること" do
        described_class.perform_now(video.id)
        video.reload
        expect(video.status).to eq("failed")
        expect(video.error_message).to include("30分")
      end
    end

    context "動画がちょうど30分(境界値)の場合" do
      let(:video) { create(:caption_video, customer: customer, status: "uploaded") }

      before do
        stub_probe(result: CaptionVideos::VideoProbe::Result.new(
          duration: CaptionVideo::MAX_DURATION_SECONDS.to_f, width: 1280, height: 720,
          has_audio_stream: true, format_name: "mp4"
        ))
        stub_audio_extractor
        allow(CaptionVideos::TranscribeJob).to receive(:perform_later)
      end

      it "時間超過にならず処理が継続すること" do
        described_class.perform_now(video.id)
        video.reload
        expect(video.status).to eq("transcribing")
      end
    end

    context "16分程度(実利用を想定した長さ)の動画の場合" do
      let(:video) { create(:caption_video, customer: customer, status: "uploaded") }

      before do
        stub_probe(result: CaptionVideos::VideoProbe::Result.new(
          duration: 16.minutes.to_f, width: 1920, height: 1080,
          has_audio_stream: true, format_name: "mp4"
        ))
        stub_audio_extractor
        allow(CaptionVideos::TranscribeJob).to receive(:perform_later)
      end

      it "時間超過にならず、音声抽出から文字起こしへ進めること" do
        described_class.perform_now(video.id)
        video.reload
        expect(video.status).to eq("transcribing")
        expect(video.duration).to eq(16.minutes.to_f)
      end
    end

    context "MP4以外の形式の場合" do
      let(:video) { create(:caption_video, customer: customer, status: "uploaded") }

      before do
        stub_probe(result: CaptionVideos::VideoProbe::Result.new(
          duration: 10.0, width: 1280, height: 720, has_audio_stream: true, format_name: "avi"
        ))
      end

      it "failedになり、形式エラーのメッセージを保存すること" do
        described_class.perform_now(video.id)
        video.reload
        expect(video.status).to eq("failed")
        expect(video.error_message).to include("MP4形式")
      end
    end

    context "音声トラックが無い場合" do
      let(:video) { create(:caption_video, customer: customer, status: "uploaded") }

      before do
        stub_probe(result: CaptionVideos::VideoProbe::Result.new(
          duration: 10.0, width: 1280, height: 720, has_audio_stream: false, format_name: "mp4"
        ))
      end

      it "failedになり、音声トラック無しのメッセージを保存すること" do
        described_class.perform_now(video.id)
        video.reload
        expect(video.status).to eq("failed")
        expect(video.error_message).to include("音声トラック")
      end
    end

    context "ffprobeが失敗する場合" do
      let(:video) { create(:caption_video, customer: customer, status: "uploaded") }

      before do
        probe_double = instance_double(CaptionVideos::VideoProbe)
        allow(probe_double).to receive(:call).and_raise(CaptionVideos::VideoProbe::ProbeError, "ffprobe failed")
        allow(CaptionVideos::VideoProbe).to receive(:new).and_return(probe_double)
      end

      it "failedになること" do
        described_class.perform_now(video.id)
        expect(video.reload.status).to eq("failed")
      end
    end

    context "音声抽出が失敗する場合" do
      let(:video) { create(:caption_video, customer: customer, status: "uploaded") }

      before do
        stub_probe
        allow(CaptionVideos::AudioExtractor).to receive(:new).and_raise(CaptionVideos::AudioExtractor::ExtractionError, "boom")
      end

      it "failedになり、ユーザー向けメッセージ(内部エラー詳細を含まない)を保存すること" do
        described_class.perform_now(video.id)
        video.reload
        expect(video.status).to eq("failed")
        expect(video.error_message).to include("音声の準備に失敗")
        expect(video.error_message).not_to include("boom")
      end
    end

    context "予期しない例外が発生する場合" do
      let(:video) { create(:caption_video, customer: customer, status: "uploaded") }

      before do
        allow(CaptionVideos::VideoProbe).to receive(:new).and_raise(StandardError, "unexpected")
      end

      it "例外を外へ漏らさずfailedにすること" do
        expect { described_class.perform_now(video.id) }.not_to raise_error
        expect(video.reload.status).to eq("failed")
      end
    end
  end
end
