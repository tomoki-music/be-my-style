require "rails_helper"

RSpec.describe CaptionVideos::TranscribeJob, type: :job do
  let(:customer) { create(:customer) }

  def build_video_with_audio(status: "transcribing")
    video = create(:caption_video, customer: customer, status: status, duration: 60.0)
    video.extracted_audio.attach(io: StringIO.new("dummy audio"), filename: "audio.mp3", content_type: "audio/mpeg")
    video
  end

  def stub_transcription_client(segments)
    client = instance_double(CaptionVideos::TranscriptionClient)
    allow(client).to receive(:transcribe).and_return(segments)
    allow(CaptionVideos::TranscriptionClient).to receive(:new).and_return(client)
    client
  end

  describe "#perform" do
    context "caption_videoが存在しない場合" do
      it "何もしない" do
        expect { described_class.perform_now(0) }.not_to raise_error
      end
    end

    context "statusがtranscribingでない場合(冪等性)" do
      it "何もしない" do
        video = create(:caption_video, customer: customer, status: "ready_for_edit")
        expect(CaptionVideos::TranscriptionClient).not_to receive(:new)
        described_class.perform_now(video.id)
      end
    end

    context "既にtranscribed_atがある場合(二重課金防止)" do
      it "OpenAIを呼ばないこと" do
        video = build_video_with_audio
        video.update!(transcribed_at: Time.current)
        expect(CaptionVideos::TranscriptionClient).not_to receive(:new)
        described_class.perform_now(video.id)
      end
    end

    context "extracted_audioが無い場合" do
      it "何もしない" do
        video = create(:caption_video, customer: customer, status: "transcribing")
        expect(CaptionVideos::TranscriptionClient).not_to receive(:new)
        described_class.perform_now(video.id)
      end
    end

    context "正常系" do
      let(:video) { build_video_with_audio }
      let(:segments) { [{ start: 0.0, end: 2.0, text: "こんにちは" }] }

      before { stub_transcription_client(segments) }

      it "video_captionsを作成すること" do
        expect { described_class.perform_now(video.id) }.to change { video.reload.video_captions.count }.from(0).to(1)
      end

      it "テロップの時刻・本文が保存されること" do
        described_class.perform_now(video.id)
        caption = video.reload.video_captions.first
        expect(caption.start_time.to_f).to eq(0.0)
        expect(caption.end_time.to_f).to eq(2.0)
        expect(caption.text).to eq("こんにちは")
        expect(caption.caption_type).to eq("normal")
      end

      it "statusをready_for_editにしtranscribed_atを設定すること" do
        described_class.perform_now(video.id)
        video.reload
        expect(video.status).to eq("ready_for_edit")
        expect(video.transcribed_at).to be_present
      end

      it "extracted_audioをpurgeすること" do
        described_class.perform_now(video.id)
        expect(video.reload.extracted_audio).not_to be_attached
      end
    end

    context "再実行時に二重登録しないこと(冪等性)" do
      let(:video) { build_video_with_audio }

      it "既存のvideo_captionsを一度クリアしてから作り直すこと" do
        create(:video_caption, caption_video: video, text: "古いテロップ")
        stub_transcription_client([{ start: 0.0, end: 1.0, text: "新しいテロップ" }])

        described_class.perform_now(video.id)

        expect(video.reload.video_captions.count).to eq(1)
        expect(video.video_captions.first.text).to eq("新しいテロップ")
      end
    end

    context "OpenAIが一時的にタイムアウトする場合" do
      let(:video) { build_video_with_audio }

      before do
        client = instance_double(CaptionVideos::TranscriptionClient)
        allow(client).to receive(:transcribe).and_raise(CaptionVideos::TranscriptionClient::TimeoutError, "timeout")
        allow(CaptionVideos::TranscriptionClient).to receive(:new).and_return(client)
      end

      it "MAX_RETRY_ATTEMPTS回まで限定的にリトライすること" do
        allow(described_class).to receive(:set).and_return(described_class)
        allow(described_class).to receive(:perform_later)

        described_class.perform_now(video.id, 0)

        expect(described_class).to have_received(:perform_later).with(video.id, 1)
        expect(video.reload.status).to eq("transcribing")
      end

      it "リトライ上限に達したらfailedにすること" do
        described_class.perform_now(video.id, described_class::MAX_RETRY_ATTEMPTS)
        expect(video.reload.status).to eq("failed")
      end
    end

    context "APIキー未設定の場合" do
      let(:video) { build_video_with_audio }

      before do
        client = instance_double(CaptionVideos::TranscriptionClient)
        allow(client).to receive(:transcribe).and_raise(CaptionVideos::TranscriptionClient::ConfigurationError, "no key")
        allow(CaptionVideos::TranscriptionClient).to receive(:new).and_return(client)
      end

      it "即座にfailedにし、リトライしないこと" do
        allow(described_class).to receive(:perform_later)
        described_class.perform_now(video.id)

        expect(video.reload.status).to eq("failed")
        expect(described_class).not_to have_received(:perform_later)
      end
    end

    context "レスポンス形式が不正な場合" do
      let(:video) { build_video_with_audio }

      before do
        client = instance_double(CaptionVideos::TranscriptionClient)
        allow(client).to receive(:transcribe).and_raise(CaptionVideos::TranscriptionClient::ResponseFormatError, "bad format")
        allow(CaptionVideos::TranscriptionClient).to receive(:new).and_return(client)
      end

      it "failedにすること" do
        described_class.perform_now(video.id)
        expect(video.reload.status).to eq("failed")
      end
    end

    context "予期しない例外が発生する場合" do
      let(:video) { build_video_with_audio }

      before do
        allow(CaptionVideos::TranscriptionClient).to receive(:new).and_raise(StandardError, "unexpected")
      end

      it "例外を外へ漏らさずfailedにすること" do
        expect { described_class.perform_now(video.id) }.not_to raise_error
        expect(video.reload.status).to eq("failed")
      end
    end
  end
end
