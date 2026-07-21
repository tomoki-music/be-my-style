require "rails_helper"

RSpec.describe Chat::MentionHydrator, type: :service do
  def call(content)
    described_class.call(content)
  end

  it "1件のメンションを@表示名へ変換しMention Stateを復元すること" do
    result = call("こんにちは [@tomoki](customer:123) さん")

    expect(result.content).to eq "こんにちは @tomoki さん"
    expect(result.mentions).to eq [{ customerId: 123, username: "tomoki", start: 6, end: 13 }]
  end

  it "複数メンションをそれぞれ変換すること" do
    result = call("[@a](customer:1) と [@b](customer:2)")

    expect(result.content).to eq "@a と @b"
    expect(result.mentions).to eq [
      { customerId: 1, username: "a", start: 0, end: 2 },
      { customerId: 2, username: "b", start: 5, end: 7 }
    ]
  end

  it "同一customerの複数回メンションをそれぞれ出現位置ごとに保持すること" do
    result = call("[@a](customer:1)[@a](customer:1)")

    expect(result.content).to eq "@a@a"
    expect(result.mentions).to eq [
      { customerId: 1, username: "a", start: 0, end: 2 },
      { customerId: 1, username: "a", start: 2, end: 4 }
    ]
  end

  it "同じusernameで異なるcustomer IDを区別して保持すること" do
    result = call("[@tomo](customer:1) [@tomo](customer:2)")

    expect(result.content).to eq "@tomo @tomo"
    expect(result.mentions.map { |m| m[:customerId] }).to eq [1, 2]
    expect(result.mentions.map { |m| m[:username] }).to eq %w[tomo tomo]
  end

  it "通常のMarkdownリンクを変更しないこと" do
    result = call("[Google](https://google.com) を見て")

    expect(result.content).to eq "[Google](https://google.com) を見て"
    expect(result.mentions).to eq []
  end

  it "インラインコード内のメンション記法を変換しないこと" do
    result = call("これは `[@tomoki](customer:123)` です")

    expect(result.content).to eq "これは `[@tomoki](customer:123)` です"
    expect(result.mentions).to eq []
  end

  it "コードブロック内のメンション記法を変換しないこと" do
    content = "説明\n```\n[@tomoki](customer:123)\n```\n終わり"
    result = call(content)

    expect(result.content).to eq content
    expect(result.mentions).to eq []
  end

  it "壊れた内部記法(閉じ括弧なし)を変換しないこと" do
    result = call("[@tomoki(customer:123) さん")

    expect(result.content).to eq "[@tomoki(customer:123) さん"
    expect(result.mentions).to eq []
  end

  it "壊れた内部記法(閉じ丸括弧なし)を変換しないこと" do
    result = call("[@tomoki](customer:123 さん")

    expect(result.content).to eq "[@tomoki](customer:123 さん"
    expect(result.mentions).to eq []
  end

  it "customer IDが数値でない場合は変換しないこと" do
    result = call("[@tomoki](customer:abc) さん")

    expect(result.content).to eq "[@tomoki](customer:abc) さん"
    expect(result.mentions).to eq []
  end

  it "存在しないcustomer IDでも例外を起こさずMention Stateへ復元すること" do
    result = call("[@deleted-user](customer:999999)")

    expect(result.content).to eq "@deleted-user"
    expect(result.mentions).to eq [{ customerId: 999_999, username: "deleted-user", start: 0, end: 13 }]
  end

  it "usernameが空でも例外を起こさないこと" do
    result = call("[@](customer:1)")

    expect(result.content).to eq "@"
    expect(result.mentions).to eq [{ customerId: 1, username: "", start: 0, end: 1 }]
  end

  it "nilを渡しても例外を起こさず空文字を返すこと" do
    result = call(nil)

    expect(result.content).to eq ""
    expect(result.mentions).to eq []
  end

  it "空文字を渡しても例外を起こさないこと" do
    result = call("")

    expect(result.content).to eq ""
    expect(result.mentions).to eq []
  end

  it "日本語を含む本文でstart/endが正確であること" do
    result = call("こんにちは[@tomoki](customer:123)さん")

    expect(result.content).to eq "こんにちは@tomokiさん"
    mention = result.mentions.first
    expect(result.content[mention[:start]...mention[:end]]).to eq "@tomoki"
  end

  it "絵文字(サロゲートペア)を含む本文でUTF-16コード単位ベースのstart/endになること" do
    result = call("😀[@tomoki](customer:123)")

    expect(result.content).to eq "😀@tomoki"
    # "😀" はUTF-16では2コード単位(サロゲートペア)になるため、メンションのstartは2から始まる
    expect(result.mentions).to eq [{ customerId: 123, username: "tomoki", start: 2, end: 9 }]
  end

  it "先頭のメンションのstart/endが0から始まること" do
    result = call("[@a](customer:1) の投稿")

    expect(result.mentions.first[:start]).to eq 0
    expect(result.mentions.first[:end]).to eq 2
  end

  it "末尾のメンションのstart/endが文字列末尾と一致すること" do
    result = call("こんにちは [@a](customer:1)")

    mention = result.mentions.first
    expect(mention[:end]).to eq result.content.length
  end

  it "内部記法とプレーンな@usernameが混在していても内部記法だけを変換すること" do
    result = call("[@a](customer:1) @b さん")

    expect(result.content).to eq "@a @b さん"
    expect(result.mentions).to eq [{ customerId: 1, username: "a", start: 0, end: 2 }]
  end
end
