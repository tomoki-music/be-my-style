require "rails_helper"

RSpec.describe Singing::RecapMovieRenderer, type: :service do
  let(:customer) { create(:customer, domain_name: "singing") }
  let(:movie)    { create(:singing_generated_recap_movie, customer: customer, year: 2025) }

  subject(:renderer) { described_class.new(movie) }

  let(:tmp_base) { Dir.mktmpdir("recap_renderer_spec") }

  before do
    allow(renderer).to receive(:tmp_root).and_return(tmp_base)
    # デフォルトはパス検証をスキップ（各コンテキストで必要に応じてオーバーライド）
    allow(renderer).to receive(:validate_paths!)
  end

  after { FileUtils.remove_entry(tmp_base) }

  let(:status_success) { instance_double(Process::Status, success?: true,  exitstatus: 0) }
  let(:status_failure) { instance_double(Process::Status, success?: false, exitstatus: 1) }

  def stub_open3_success
    allow(Open3).to receive(:capture3) do |*args, **_kwargs|
      out_idx = args.index("--out")
      File.write(args[out_idx + 1], "DUMMY_MP4") if out_idx
      ["stdout output", "", status_success]
    end
  end

  describe "#call" do
    context "成功パス" do
      before { stub_open3_success }

      it "status が completed になる" do
        renderer.call
        expect(movie.reload.status).to eq("completed")
      end

      it "video_file が attach される" do
        renderer.call
        expect(movie.reload.video_file).to be_attached
      end

      it "true を返す" do
        expect(renderer.call).to be true
      end

      it "generated_props が保存される" do
        renderer.call
        props = movie.reload.generated_props
        expect(props).to be_present
        expect(props["recapMovieId"]).to eq(movie.id)
        expect(props["year"]).to eq(2025)
        expect(props["theme"]).to eq("default")
        expect(props["userName"]).to eq(customer.name)
      end

      it "再生成時も generated_props が上書きされる" do
        movie.update!(generated_props: { "recapMovieId" => -1, "year" => 1999 })
        renderer.call
        expect(movie.reload.generated_props["year"]).to eq(2025)
      end
    end

    context "render コマンド失敗 (exit status != 0)" do
      before do
        allow(Open3).to receive(:capture3).and_return(["", "node error detail", status_failure])
      end

      it "status が failed になる" do
        renderer.call
        expect(movie.reload.status).to eq("failed")
      end

      it "video_file が attach されない" do
        renderer.call
        expect(movie.reload.video_file).not_to be_attached
      end

      it "false を返す" do
        expect(renderer.call).to be false
      end
    end

    context "output mp4 が存在しない (コマンドは成功)" do
      before do
        allow(Open3).to receive(:capture3).and_return(["", "", status_success])
      end

      it "status が failed になる" do
        renderer.call
        expect(movie.reload.status).to eq("failed")
      end

      it "video_file が attach されない" do
        renderer.call
        expect(movie.reload.video_file).not_to be_attached
      end

      it "false を返す" do
        expect(renderer.call).to be false
      end
    end

    context "tmp dir cleanup" do
      before { stub_open3_success }

      it "call 後に tmp_base 内に一時ファイルが残らない" do
        renderer.call
        entries = Dir.glob(File.join(tmp_base, "**", "*")).reject { |f| File.directory?(f) }
        expect(entries).to be_empty
      end
    end

    context "props.json の内容" do
      let(:captured_props) { {} }

      before do
        allow(Open3).to receive(:capture3) do |*args, **_kwargs|
          props_idx = args.index("--props")
          if props_idx
            captured_props.merge!(JSON.parse(File.read(args[props_idx + 1])))
          end
          out_idx = args.index("--out")
          File.write(args[out_idx + 1], "DUMMY") if out_idx
          ["", "", status_success]
        end
      end

      it "recapMovieId が含まれる" do
        renderer.call
        expect(captured_props["recapMovieId"]).to eq(movie.id)
      end

      it "customerId が含まれる" do
        renderer.call
        expect(captured_props["customerId"]).to eq(movie.customer_id)
      end

      it "year が含まれる" do
        renderer.call
        expect(captured_props["year"]).to eq(2025)
      end

      it "theme が含まれる" do
        renderer.call
        expect(captured_props["theme"]).to eq("default")
      end

      it "userName が含まれる" do
        renderer.call
        expect(captured_props["userName"]).to eq(customer.name)
      end

      it "diagnosisCount が含まれる" do
        renderer.call
        expect(captured_props).to have_key("diagnosisCount")
      end

      it "bestScore が含まれる（nil 許容）" do
        renderer.call
        expect(captured_props).to have_key("bestScore")
      end

      it "averageScore が含まれる（nil 許容）" do
        renderer.call
        expect(captured_props).to have_key("averageScore")
      end

      it "topGrowthMetric が含まれる（nil 許容）" do
        renderer.call
        expect(captured_props).to have_key("topGrowthMetric")
      end

      it "voiceType が含まれる（nil 許容）" do
        renderer.call
        expect(captured_props).to have_key("voiceType")
      end
    end

    context "props.json の内容 — 診断データあり" do
      let(:captured_props) { {} }

      before do
        create(:singing_diagnosis, :completed,
               customer: customer,
               overall_score: 70, pitch_score: 68, rhythm_score: 72, expression_score: 65,
               created_at: Time.zone.local(2025, 1, 10))
        create(:singing_diagnosis, :completed,
               customer: customer,
               overall_score: 85, pitch_score: 88, rhythm_score: 80, expression_score: 82,
               created_at: Time.zone.local(2025, 7, 10))

        allow(Open3).to receive(:capture3) do |*args, **_kwargs|
          props_idx = args.index("--props")
          captured_props.merge!(JSON.parse(File.read(args[props_idx + 1]))) if props_idx
          out_idx = args.index("--out")
          File.write(args[out_idx + 1], "DUMMY") if out_idx
          ["", "", status_success]
        end
      end

      it "diagnosisCount が正しい" do
        renderer.call
        expect(captured_props["diagnosisCount"]).to eq(2)
      end

      it "bestScore が最大スコアになる" do
        renderer.call
        expect(captured_props["bestScore"]).to eq(85)
      end

      it "averageScore が平均になる" do
        renderer.call
        expect(captured_props["averageScore"]).to eq(((70 + 85) / 2.0).round)
      end

      it "topGrowthMetric が最も伸びた指標のラベルを返す" do
        renderer.call
        # pitch が 68→88 で +20 が最大
        expect(captured_props["topGrowthMetric"]).to eq("音程")
      end

      it "voiceType が nil でない" do
        renderer.call
        expect(captured_props["voiceType"]).not_to be_nil
      end
    end

    context "render timeout" do
      before do
        allow(Open3).to receive(:capture3).and_raise(Timeout::Error)
      end

      it "status が failed になる" do
        renderer.call
        expect(movie.reload.status).to eq("failed")
      end

      it "error_message に timeout が含まれる" do
        renderer.call
        expect(movie.reload.error_message).to include("timeout")
      end

      it "false を返す" do
        expect(renderer.call).to be false
      end

      it "video_file が attach されない" do
        renderer.call
        expect(movie.reload.video_file).not_to be_attached
      end
    end

    context "render script が存在しない" do
      before do
        allow(renderer).to receive(:validate_paths!).and_call_original
        allow(renderer).to receive(:remotion_root).and_return(tmp_base)
        allow(renderer).to receive(:absolute_script_path).and_return(
          File.join(tmp_base, "scripts", "render_recap_movie.js")
        )
      end

      it "status が failed になる" do
        renderer.call
        expect(movie.reload.status).to eq("failed")
      end

      it "error_message に render script not found が含まれる" do
        renderer.call
        expect(movie.reload.error_message).to include("render script not found")
      end

      it "false を返す" do
        expect(renderer.call).to be false
      end
    end

    context "remotion root が存在しない" do
      before do
        allow(renderer).to receive(:validate_paths!).and_call_original
        allow(renderer).to receive(:remotion_root).and_return("/nonexistent/path/bemystyle-reel")
      end

      it "status が failed になる" do
        renderer.call
        expect(movie.reload.status).to eq("failed")
      end

      it "error_message に BEMYSTYLE_REEL_PATH not found が含まれる" do
        renderer.call
        expect(movie.reload.error_message).to include("BEMYSTYLE_REEL_PATH not found")
      end

      it "false を返す" do
        expect(renderer.call).to be false
      end
    end

    context "stderr が長い場合は truncate される" do
      let(:long_stderr) { "E" * 2000 }

      before do
        allow(Open3).to receive(:capture3).and_return(["", long_stderr, status_failure])
      end

      it "error_message が MAX_ERROR_LENGTH 以内に収まる" do
        renderer.call
        expect(movie.reload.error_message.length).to be <= described_class::MAX_ERROR_LENGTH
      end
    end
  end
end
