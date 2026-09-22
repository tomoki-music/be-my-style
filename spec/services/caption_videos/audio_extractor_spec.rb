require "rails_helper"

RSpec.describe CaptionVideos::AudioExtractor do
  let(:status_success) { instance_double(Process::Status, success?: true) }
  let(:status_failure) { instance_double(Process::Status, success?: false) }
  let(:tmp_dir) { Dir.mktmpdir("audio_extractor_spec") }
  let(:output_path) { File.join(tmp_dir, "audio.mp3") }

  after { FileUtils.remove_entry(tmp_dir) }

  describe "#call" do
    it "成功した場合はtrueを返すこと" do
      allow(Open3).to receive(:capture3) do
        File.write(output_path, "DUMMY_AUDIO")
        ["", "", status_success]
      end

      result = described_class.new(input_path: "/tmp/in.mp4", output_path: output_path).call
      expect(result).to be true
    end

    it "ffmpegが失敗した場合はExtractionErrorになること" do
      allow(Open3).to receive(:capture3).and_return(["", "ffmpeg error", status_failure])

      expect do
        described_class.new(input_path: "/tmp/in.mp4", output_path: output_path).call
      end.to raise_error(described_class::ExtractionError, /extraction failed/)
    end

    it "出力ファイルが生成されない場合はExtractionErrorになること" do
      allow(Open3).to receive(:capture3).and_return(["", "", status_success])

      expect do
        described_class.new(input_path: "/tmp/in.mp4", output_path: output_path).call
      end.to raise_error(described_class::ExtractionError, /missing or empty/)
    end

    it "出力ファイルが空の場合はExtractionErrorになること" do
      allow(Open3).to receive(:capture3) do
        FileUtils.touch(output_path)
        ["", "", status_success]
      end

      expect do
        described_class.new(input_path: "/tmp/in.mp4", output_path: output_path).call
      end.to raise_error(described_class::ExtractionError, /missing or empty/)
    end

    it "MAX_AUDIO_BYTESを超える場合はExtractionErrorになること" do
      allow(Open3).to receive(:capture3) do
        File.write(output_path, "x" * 100)
        ["", "", status_success]
      end
      stub_const("#{described_class}::MAX_AUDIO_BYTES", 10)

      expect do
        described_class.new(input_path: "/tmp/in.mp4", output_path: output_path).call
      end.to raise_error(described_class::ExtractionError, /exceeds size limit/)
    end

    it "タイムアウトした場合はExtractionErrorになること" do
      allow(Open3).to receive(:capture3).and_raise(Timeout::Error)

      expect do
        described_class.new(input_path: "/tmp/in.mp4", output_path: output_path, timeout: 1).call
      end.to raise_error(described_class::ExtractionError, /timeout/)
    end

    it "ffmpegが無い場合はExtractionErrorになること" do
      allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT)

      expect do
        described_class.new(input_path: "/tmp/in.mp4", output_path: output_path).call
      end.to raise_error(described_class::ExtractionError, /not installed/)
    end

    it "入力がMOV(.mov)でも成功すること(ffmpegはコンテナ内容を見て判定し拡張子には依存しない)" do
      allow(Open3).to receive(:capture3) do
        File.write(output_path, "DUMMY_AUDIO_FROM_MOV")
        ["", "", status_success]
      end

      result = described_class.new(input_path: "/tmp/in.mov", output_path: output_path).call
      expect(result).to be true
    end
  end

  describe "MAX_DURATION_SECONDSと音声サイズの整合性(音声分割が不要であることの根拠)" do
    it "CaptionVideo::MAX_DURATION_SECONDS一杯の動画でも、想定ビットレートでの抽出音声サイズがMAX_AUDIO_BYTES以内に収まること" do
      bitrate_bps = described_class::AUDIO_BITRATE.to_i * 1000
      estimated_bytes = CaptionVideo::MAX_DURATION_SECONDS * bitrate_bps / 8

      expect(estimated_bytes).to be < described_class::MAX_AUDIO_BYTES
    end
  end
end
