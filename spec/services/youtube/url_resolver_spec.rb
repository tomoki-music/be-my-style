require "rails_helper"

RSpec.describe Youtube::UrlResolver do
  describe ".call" do
    context "正常系" do
      {
        "watch (youtube.com)" => "https://www.youtube.com/watch?v=abcdefghijk",
        "watch (bare host)" => "https://youtube.com/watch?v=abcdefghijk",
        "youtu.be" => "https://youtu.be/abcdefghijk",
        "shorts" => "https://www.youtube.com/shorts/abcdefghijk",
        "embed" => "https://www.youtube.com/embed/abcdefghijk",
        "m.youtube.com" => "https://m.youtube.com/watch?v=abcdefghijk",
        "music.youtube.com" => "https://music.youtube.com/watch?v=abcdefghijk"
      }.each do |label, url|
        it "#{label} からvideo_idを抽出できること" do
          result = described_class.call(url)

          expect(result).not_to be_nil
          expect(result.video_id).to eq("abcdefghijk")
          expect(result.canonical_url).to eq("https://www.youtube.com/watch?v=abcdefghijk")
          expect(result.thumbnail_url).to eq("https://img.youtube.com/vi/abcdefghijk/hqdefault.jpg")
        end
      end
    end

    context "クエリパラメータ付き" do
      {
        "youtu.be + si" => "https://youtu.be/abcdefghijk?si=xxxx",
        "watch + t" => "https://www.youtube.com/watch?v=abcdefghijk&t=30s",
        "watch + list" => "https://www.youtube.com/watch?v=abcdefghijk&list=xxxx"
      }.each do |label, url|
        it "#{label} でもvideo_idを抽出できること" do
          result = described_class.call(url)

          expect(result).not_to be_nil
          expect(result.video_id).to eq("abcdefghijk")
        end
      end
    end

    context "異常系" do
      [nil, "", "not a url", "https://example.com/watch?v=abcdefghijk",
       "https://youtube.com.evil.example/watch?v=abcdefghijk",
       "javascript:alert(1)", "https://youtu.be/", "https://www.youtube.com/watch"].each do |url|
        it "#{url.inspect} はnilを返すこと" do
          expect(described_class.call(url)).to be_nil
        end
      end
    end

    context "境界値" do
      it "動画IDが11文字未満の場合はnilを返すこと" do
        expect(described_class.call("https://youtu.be/short")).to be_nil
      end

      it "動画IDが11文字を超える場合はnilを返すこと" do
        expect(described_class.call("https://youtu.be/toolongvideoid")).to be_nil
      end

      it "非常に長いURLでも例外にならずnilを返すこと" do
        long_url = "https://example.com/#{'a' * 5000}"
        expect(described_class.call(long_url)).to be_nil
      end

      it "日本語を含むURLでも例外にならずnilを返すこと" do
        expect(described_class.call("https://www.youtube.com/watch?v=日本語です")).to be_nil
      end

      it "URI解析不能な文字列でも例外にならずnilを返すこと" do
        expect(described_class.call("https://[invalid")).to be_nil
      end

      it "前後に空白があるURLでもvideo_idを抽出できること" do
        result = described_class.call("  https://youtu.be/abcdefghijk  ")

        expect(result).not_to be_nil
        expect(result.video_id).to eq("abcdefghijk")
      end
    end
  end
end
