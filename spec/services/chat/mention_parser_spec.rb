require "rails_helper"

RSpec.describe Chat::MentionParser, type: :service do
  def parse(content)
    described_class.call(content)
  end

  it "正しくメンションのcustomer_idを抽出すること" do
    expect(parse("[@Tomoki](customer:123) こんにちは")).to eq [123]
  end

  it "複数ユーザーへのメンションをすべて抽出すること" do
    expect(parse("[@Aさん](customer:1) と [@Bさん](customer:2)")).to eq [1, 2]
  end

  it "同一ユーザーへの重複メンションは1件に排除すること" do
    expect(parse("[@Aさん](customer:1) [@Aさん](customer:1)")).to eq [1]
  end

  it "IDが数字でない不正な記法は無視すること" do
    expect(parse("[@Tomoki](customer:abc)")).to eq []
  end

  it "通常のMarkdownリンクはメンションとして抽出しないこと" do
    expect(parse("[BeMyStyle](https://be-my-style.com)")).to eq []
  end

  it "メールアドレスをメンションとして誤抽出しないこと" do
    expect(parse("test@example.com")).to eq []
  end

  it "コードブロック内のメンション記法は抽出しないこと" do
    expect(parse("```\n[@Tomoki](customer:123)\n```")).to eq []
  end

  it "インラインコード内のメンション記法は抽出しないこと" do
    expect(parse("`[@Tomoki](customer:123)`")).to eq []
  end

  it "空文字・nilは空配列を返すこと" do
    expect(parse("")).to eq []
    expect(parse(nil)).to eq []
  end
end
