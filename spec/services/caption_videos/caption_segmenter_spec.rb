require "rails_helper"

RSpec.describe CaptionVideos::CaptionSegmenter do
  describe ".call" do
    it "短いsegmentはそのまま1件のテロップになること" do
      segments = [{ start: 0.0, end: 2.0, text: "こんにちは" }]
      captions = described_class.call(segments)

      expect(captions.size).to eq(1)
      expect(captions.first[:text]).to eq("こんにちは")
      expect(captions.first[:start_time]).to eq(0.0)
      expect(captions.first[:end_time]).to eq(2.0)
    end

    it "空文字のsegmentは無視されること" do
      segments = [{ start: 0.0, end: 2.0, text: "   " }]
      expect(described_class.call(segments)).to eq([])
    end

    it "start >= endのsegmentは無視されること" do
      segments = [{ start: 5.0, end: 5.0, text: "テスト" }]
      expect(described_class.call(segments)).to eq([])
    end

    it "元の発言内容を変更しない(結合すると元テキストに戻ること)" do
      text = "今日はとても良い天気で、みんなで公園に散歩に行きました。とても楽しかったです。"
      segments = [{ start: 0.0, end: 10.0, text: text }]
      captions = described_class.call(segments)

      rejoined = captions.map { |c| c[:text].delete("\n") }.join
      expect(rejoined).to eq(text)
    end

    it "1テロップは最大2行であること" do
      text = "今日はとても良い天気で、みんなで公園に散歩に行きました。とても楽しかったです。"
      segments = [{ start: 0.0, end: 10.0, text: text }]
      captions = described_class.call(segments)

      captions.each do |caption|
        expect(caption[:text].split("\n").size).to be <= 2
      end
    end

    it "長い発言は複数テロップへ分割され、時刻が重複・逆転しないこと" do
      text = "今日はとても良い天気で、みんなで公園に散歩に行きました。とても楽しかったです。また行きたいと思います。"
      segments = [{ start: 10.0, end: 20.0, text: text }]
      captions = described_class.call(segments)

      expect(captions.size).to be > 1
      captions.each_cons(2) do |a, b|
        expect(b[:start_time]).to be >= a[:end_time]
      end
      expect(captions.first[:start_time]).to eq(10.0)
      expect(captions.last[:end_time]).to eq(20.0)
    end

    it "空文字のテロップを作らないこと" do
      text = "、、、"
      segments = [{ start: 0.0, end: 1.0, text: text }]
      captions = described_class.call(segments)

      captions.each { |c| expect(c[:text]).not_to be_blank }
    end

    it "複数segmentを順番通りに処理すること" do
      segments = [
        { start: 0.0, end: 2.0, text: "最初の発言" },
        { start: 2.0, end: 4.0, text: "次の発言" }
      ]
      captions = described_class.call(segments)

      expect(captions.map { |c| c[:text] }).to eq(%w[最初の発言 次の発言])
    end
  end
end
