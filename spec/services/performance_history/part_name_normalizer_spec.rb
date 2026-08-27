require 'rails_helper'

RSpec.describe PerformanceHistory::PartNameNormalizer do
  describe '.normalize' do
    it '既にJoinPart::NAME_OPTIONSの値であれば、そのまま返すこと' do
      JoinPart::NAME_OPTIONS.each do |name|
        expect(described_class.normalize(name)).to eq name
      end
    end

    it '安全な英語略称を現行パートへ変換すること' do
      expect(described_class.normalize("Vo")).to eq "Vocal"
      expect(described_class.normalize("Gt")).to eq "Guitar"
      expect(described_class.normalize("Ba")).to eq "Bass"
      expect(described_class.normalize("Dr")).to eq "Drums"
      expect(described_class.normalize("Key")).to eq "Keyboard"
    end

    it '大文字小文字が異なっても安全な略称を変換すること' do
      expect(described_class.normalize("vo")).to eq "Vocal"
      expect(described_class.normalize("VO")).to eq "Vocal"
    end

    it '安全な日本語表記を現行パートへ変換すること' do
      expect(described_class.normalize("ボーカル")).to eq "Vocal"
      expect(described_class.normalize("ギター")).to eq "Guitar"
      expect(described_class.normalize("ベース")).to eq "Bass"
      expect(described_class.normalize("ドラム")).to eq "Drums"
      expect(described_class.normalize("ドラムス")).to eq "Drums"
      expect(described_class.normalize("キーボード")).to eq "Keyboard"
    end

    it '意味を一意に決められない値は勝手に一致させず、nilを返すこと' do
      %w[Cho Chorus コーラス Percussion].each do |ambiguous|
        expect(described_class.normalize(ambiguous)).to be_nil
      end
      expect(described_class.normalize("Acoustic Guitar")).to be_nil
    end

    it '空文字・nilはnilを返すこと' do
      expect(described_class.normalize(nil)).to be_nil
      expect(described_class.normalize("")).to be_nil
      expect(described_class.normalize("   ")).to be_nil
    end
  end
end
