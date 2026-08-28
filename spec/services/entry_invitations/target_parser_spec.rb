require 'rails_helper'

RSpec.describe EntryInvitations::TargetParser do
  describe ".parse" do
    it "正しい形式を Integer 3つ組へ変換する" do
      expect(described_class.parse(["12:34:56", "12:34:78"]))
        .to eq [[12, 34, 56], [12, 34, 78]]
    end

    it "重複を uniq する" do
      expect(described_class.parse(["1:2:3", "1:2:3"])).to eq [[1, 2, 3]]
    end

    it "厳格な形式(\\A\\d+:\\d+:\\d+\\z)以外は捨てる" do
      expect(described_class.parse([
        "1:2:3",
        "1:2",
        "1:2:3:4",
        "a:b:c",
        "-1:2:3",
        " 1:2:3 ",
        "1 : 2 : 3",
        ""
      ])).to eq [[1, 2, 3]]
    end

    it "nil・配列以外は空配列を返す（例外を起こさない）" do
      expect(described_class.parse(nil)).to eq []
      expect(described_class.parse({ "0" => "1:2:3" })).to eq []
      expect(described_class.parse(123)).to eq []
    end

    it "文字列単体も受け付ける" do
      expect(described_class.parse("7:8:9")).to eq [[7, 8, 9]]
    end

    it "MAX_TARGETS は現実的な候補数を十分上回る" do
      expect(described_class::MAX_TARGETS).to be >= 100
    end
  end
end
