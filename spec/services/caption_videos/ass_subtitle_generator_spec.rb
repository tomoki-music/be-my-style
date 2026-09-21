require "rails_helper"

RSpec.describe CaptionVideos::AssSubtitleGenerator do
  let(:caption_video) { create(:caption_video, width: 1920, height: 1080) }

  describe ".call" do
    it "PlayResX/PlayResYに動画の解像度を設定すること" do
      captions = [create(:video_caption, caption_video: caption_video, start_time: 0.0, end_time: 1.0, text: "テスト")]
      ass = described_class.call(captions, width: 1920, height: 1080)

      expect(ass).to include("PlayResX: 1920")
      expect(ass).to include("PlayResY: 1080")
    end

    it "幅・高さが不正な場合はデフォルト値を使うこと" do
      ass = described_class.call([], width: nil, height: 0)
      expect(ass).to include("PlayResX: 1280")
      expect(ass).to include("PlayResY: 720")
    end

    it "Dialogue行にテロップ本文が含まれること" do
      captions = [create(:video_caption, caption_video: caption_video, start_time: 1.5, end_time: 3.25, text: "こんにちは")]
      ass = described_class.call(captions, width: 1920, height: 1080)

      expect(ass).to include("こんにちは")
      expect(ass).to match(/Dialogue: 0,0:00:01\.50,0:00:03\.25,Default/)
    end

    it "改行を含むテキストは\\Nへ変換され、Dialogue行が1物理行に収まること" do
      captions = [create(:video_caption, caption_video: caption_video, start_time: 0.0, end_time: 1.0, text: "1行目\n2行目")]
      ass = described_class.call(captions, width: 1920, height: 1080)

      dialogue_line = ass.lines.find { |line| line.start_with?("Dialogue:") }
      expect(dialogue_line).to include("1行目\\N2行目")
      expect(dialogue_line.scan("\n").size).to eq(1) # 行末の改行のみ(生の改行を含まない)
    end

    it "{ } を含むユーザー入力を全角へ置換し、ASSオーバーライドタグとして解釈されないこと" do
      captions = [create(:video_caption, caption_video: caption_video, start_time: 0.0, end_time: 1.0, text: "{\\pos(0,0)}注入テスト")]
      ass = described_class.call(captions, width: 1920, height: 1080)

      dialogue_line = ass.lines.find { |line| line.start_with?("Dialogue:") }
      expect(dialogue_line).not_to include("{\\pos(0,0)}")
      expect(dialogue_line).to include("\uFF5B") # ｛ (全角)
    end

    it "バックスラッシュを含むユーザー入力を全角へ置換すること" do
      captions = [create(:video_caption, caption_video: caption_video, start_time: 0.0, end_time: 1.0, text: "C:\\path\\to\\file")]
      ass = described_class.call(captions, width: 1920, height: 1080)

      dialogue_line = ass.lines.find { |line| line.start_with?("Dialogue:") }
      expect(dialogue_line).to include("\uFF3C") # ＼ (全角)
      expect(dialogue_line).not_to match(/C:\\path/)
    end

    it "3行以上のテキストは2行までに切り詰められること" do
      captions = [create(:video_caption, caption_video: caption_video, start_time: 0.0, end_time: 1.0, text: "1行目\n2行目\n3行目")]
      ass = described_class.call(captions, width: 1920, height: 1080)

      dialogue_line = ass.lines.find { |line| line.start_with?("Dialogue:") }
      expect(dialogue_line).not_to include("3行目")
    end

    it "複数テロップが表示順どおりにEventsへ出力されること" do
      c1 = create(:video_caption, caption_video: caption_video, start_time: 0.0, end_time: 1.0, text: "A", display_order: 0)
      c2 = create(:video_caption, caption_video: caption_video, start_time: 1.0, end_time: 2.0, text: "B", display_order: 1)
      ass = described_class.call([c1, c2], width: 1920, height: 1080)

      dialogue_lines = ass.lines.select { |line| line.start_with?("Dialogue:") }
      expect(dialogue_lines.size).to eq(2)
      expect(dialogue_lines[0]).to include("A")
      expect(dialogue_lines[1]).to include("B")
    end
  end
end
