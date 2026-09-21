require "rails_helper"

RSpec.describe CaptionVideos::VideoRenderer do
  let(:status_success) { instance_double(Process::Status, success?: true) }
  let(:status_failure) { instance_double(Process::Status, success?: false) }
  let(:tmp_dir) { Dir.mktmpdir("video_renderer_spec") }
  let(:output_path) { File.join(tmp_dir, "out.mp4") }

  after { FileUtils.remove_entry(tmp_dir) }

  subject(:renderer) do
    described_class.new(input_path: "/tmp/in.mp4", ass_path: "/tmp/subs.ass", output_path: output_path)
  end

  describe "#call" do
    it "成功した場合はtrueを返し出力ファイルが存在すること" do
      allow(Open3).to receive(:capture3) do
        File.write(output_path, "DUMMY_MP4")
        ["", "", status_success]
      end

      expect(renderer.call).to be true
      expect(File.exist?(output_path)).to be true
    end

    it "ffmpegが失敗した場合はRenderErrorになること" do
      allow(Open3).to receive(:capture3).and_return(["", "encode error", status_failure])

      expect { renderer.call }.to raise_error(described_class::RenderError, /render failed/)
    end

    it "出力ファイルが生成されない場合はRenderErrorになること" do
      allow(Open3).to receive(:capture3).and_return(["", "", status_success])

      expect { renderer.call }.to raise_error(described_class::RenderError, /missing or empty/)
    end

    it "タイムアウトした場合はRenderErrorになること" do
      allow(Open3).to receive(:capture3).and_raise(Timeout::Error)

      renderer = described_class.new(input_path: "/tmp/in.mp4", ass_path: "/tmp/subs.ass", output_path: output_path, timeout: 1)
      expect { renderer.call }.to raise_error(described_class::RenderError, /timeout/)
    end

    it "ffmpegが無い場合はRenderErrorになること" do
      allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT)

      expect { renderer.call }.to raise_error(described_class::RenderError, /not installed/)
    end

    it "stderrをMAX_ERROR_LENGTH以内にtruncateすること" do
      allow(Open3).to receive(:capture3).and_return(["", "E" * 2000, status_failure])

      begin
        renderer.call
      rescue described_class::RenderError => e
        expect(e.message.length).to be <= described_class::MAX_ERROR_LENGTH + "render failed: ".length
      end
    end

    it "ass_pathの':'をffmpegフィルタ用にエスケープしてコマンドへ渡すこと" do
      captured_vf = nil
      allow(Open3).to receive(:capture3) do |*args|
        vf_idx = args.index("-vf")
        captured_vf = args[vf_idx + 1] if vf_idx
        File.write(output_path, "DUMMY_MP4")
        ["", "", status_success]
      end

      renderer = described_class.new(input_path: "/tmp/in.mp4", ass_path: "/tmp/sub:dir/subs.ass", output_path: output_path)
      renderer.call

      expect(captured_vf).to eq("ass=/tmp/sub\\:dir/subs.ass")
    end
  end
end
