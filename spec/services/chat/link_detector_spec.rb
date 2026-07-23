require "rails_helper"

RSpec.describe Chat::LinkDetector, type: :service do
  def detect(content)
    described_class.call(content)
  end

  it "通常のwatch URLから動画IDを抽出すること" do
    result = detect("見て https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    expect(result.size).to eq 1
    expect(result.first.provider).to eq :youtube
    expect(result.first.external_id).to eq "dQw4w9WgXcQ"
    expect(result.first.url).to eq "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
  end

  it "youtu.be短縮URLから動画IDを抽出すること" do
    result = detect("https://youtu.be/dQw4w9WgXcQ")
    expect(result.first.external_id).to eq "dQw4w9WgXcQ"
  end

  it "Shorts URLから動画IDを抽出すること" do
    result = detect("https://www.youtube.com/shorts/dQw4w9WgXcQ")
    expect(result.first.external_id).to eq "dQw4w9WgXcQ"
  end

  it "Live URLから動画IDを抽出すること" do
    result = detect("https://www.youtube.com/live/dQw4w9WgXcQ")
    expect(result.first.external_id).to eq "dQw4w9WgXcQ"
  end

  it "クエリパラメータ・フラグメントを無視して正規化すること" do
    result = detect("https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=30s&list=PLxxxx#foo")
    expect(result.first.url).to eq "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
  end

  it "Markdownリンク記法内のURLも抽出すること" do
    result = detect("[この曲](https://www.youtube.com/watch?v=dQw4w9WgXcQ)最高")
    expect(result.first.external_id).to eq "dQw4w9WgXcQ"
  end

  it "複数の異なるURLをすべて抽出すること" do
    result = detect(<<~TEXT)
      https://www.youtube.com/watch?v=aaaaaaaaaaa
      https://youtu.be/bbbbbbbbbbb
    TEXT
    expect(result.map(&:external_id)).to eq %w[aaaaaaaaaaa bbbbbbbbbbb]
  end

  it "同一動画の重複URLは1件に排除すること" do
    result = detect("https://youtu.be/dQw4w9WgXcQ https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    expect(result.size).to eq 1
  end

  it "最大件数(3件)を超えるURLは打ち切ること" do
    result = detect(
      (1..5).map { |i| "https://youtu.be/#{format('vid%08d', i)}" }.join(" ")
    )
    expect(result.size).to eq 3
  end

  it "playlist URLは対象外とすること" do
    result = detect("https://www.youtube.com/playlist?list=PLxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")
    expect(result).to eq []
  end

  it "YouTube以外のドメインは無視すること" do
    result = detect("https://example.com/watch?v=dQw4w9WgXcQ")
    expect(result).to eq []
  end

  it "HTTPS以外のプロトコルは無視すること" do
    result = detect("http://www.youtube.com/watch?v=dQw4w9WgXcQ")
    expect(result).to eq []
  end

  it "不正なURLでも例外を発生させないこと" do
    expect { detect("https://[invalid") }.not_to raise_error
    expect(detect("https://[invalid")).to eq []
  end

  it "URLを含まない本文は空配列を返すこと" do
    expect(detect("こんにちは")).to eq []
  end

  it "空文字・nilは空配列を返すこと" do
    expect(detect("")).to eq []
    expect(detect(nil)).to eq []
  end
end
