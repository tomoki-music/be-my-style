require "rails_helper"

RSpec.describe CaptionVideos::VideoProbe do
  let(:status_success) { instance_double(Process::Status, success?: true) }
  let(:status_failure) { instance_double(Process::Status, success?: false) }

  let(:ffprobe_json) do
    {
      format: { duration: "12.345", format_name: "mov,mp4,m4a,3gp,3g2,mj2" },
      streams: [
        { codec_type: "video", width: 1920, height: 1080 },
        { codec_type: "audio" }
      ]
    }.to_json
  end

  describe "#call" do
    it "動画の長さ・解像度・音声トラック有無を返すこと" do
      allow(Open3).to receive(:capture3).and_return([ffprobe_json, "", status_success])

      result = described_class.new("/tmp/fake.mp4").call

      expect(result.duration).to eq(12.345)
      expect(result.width).to eq(1920)
      expect(result.height).to eq(1080)
      expect(result.has_audio_stream).to be true
      expect(result.format_name).to include("mp4")
    end

    it "音声トラックが無い場合はhas_audio_streamがfalseであること" do
      json = {
        format: { duration: "5.0", format_name: "mov,mp4,m4a,3gp,3g2,mj2" },
        streams: [{ codec_type: "video", width: 640, height: 360 }]
      }.to_json
      allow(Open3).to receive(:capture3).and_return([json, "", status_success])

      result = described_class.new("/tmp/fake.mp4").call
      expect(result.has_audio_stream).to be false
    end

    it "動画トラックが無い場合はProbeErrorになること" do
      json = { format: { duration: "5.0" }, streams: [{ codec_type: "audio" }] }.to_json
      allow(Open3).to receive(:capture3).and_return([json, "", status_success])

      expect { described_class.new("/tmp/fake.mp4").call }.to raise_error(described_class::ProbeError)
    end

    it "ffprobeが失敗した場合はProbeErrorになること" do
      allow(Open3).to receive(:capture3).and_return(["", "invalid data", status_failure])

      expect { described_class.new("/tmp/fake.mp4").call }.to raise_error(described_class::ProbeError)
    end

    it "不正なJSONの場合はProbeErrorになること" do
      allow(Open3).to receive(:capture3).and_return(["not json", "", status_success])

      expect { described_class.new("/tmp/fake.mp4").call }.to raise_error(described_class::ProbeError)
    end

    it "タイムアウトした場合はProbeErrorになること" do
      allow(Open3).to receive(:capture3).and_raise(Timeout::Error)

      expect { described_class.new("/tmp/fake.mp4", timeout: 1).call }.to raise_error(described_class::ProbeError, /timeout/)
    end

    it "ffprobeがインストールされていない場合はProbeErrorになること" do
      allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT)

      expect { described_class.new("/tmp/fake.mp4").call }.to raise_error(described_class::ProbeError, /not installed/)
    end
  end
end
