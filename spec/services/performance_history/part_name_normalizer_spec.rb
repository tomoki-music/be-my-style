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

    it 'Lead/Rhythmの区別付きギター表記(Guitar(Lead)/Guitar(Lythm))を検索用にGuitarへ寄せること' do
      expect(described_class.normalize("Guitar(Lead)")).to eq "Guitar"
      expect(described_class.normalize("Guitar(Lythm)")).to eq "Guitar"
      expect(described_class.normalize("Guitar(Rhythm)")).to eq "Guitar"
    end

    it 'ギター区別表記の空白ゆれ・大文字小文字ゆれも吸収すること' do
      expect(described_class.normalize("guitar (lead)")).to eq "Guitar"
      expect(described_class.normalize(" Guitar(Lythm) ")).to eq "Guitar"
      expect(described_class.normalize("Lead Guitar")).to eq "Guitar"
    end

    it '本番調査で確認したレガシー自由入力(綴り誤り・truncation・連番)を現行パートへ変換すること' do
      {
        "Durms" => "Drums",
        "Guiar" => "Guitar",
        "Guigar" => "Guitar",
        "Gutar" => "Guitar",
        "Guitar1" => "Guitar",
        "Guitar2" => "Guitar",
        "Guitar(リード)" => "Guitar",
        "Guitar(リズム)" => "Guitar",
        "Keyboad" => "Keyboard",
        "Keyborad" => "Keyboard",
        "Keyobard" => "Keyboard",
        "Voca" => "Vocal",
        "Vocai" => "Vocal"
      }.each do |raw, expected|
        expect(described_class.normalize(raw)).to eq(expected), "#{raw.inspect} は #{expected} になるべき"
      end
    end

    it 'レガシー表記も大文字小文字の違いを吸収すること' do
      expect(described_class.normalize("DURMS")).to eq "Drums"
      expect(described_class.normalize("VOCAI")).to eq "Vocal"
      expect(described_class.normalize("KeyBoad")).to eq "Keyboard"
    end

    it 'レガシー表記の前後空白も既存仕様どおり処理されること' do
      expect(described_class.normalize("  Gutar ")).to eq "Guitar"
      expect(described_class.normalize(" Voca")).to eq "Vocal"
    end

    it '"参加します🙌" はパート名ではないためnilのままにすること' do
      expect(described_class.normalize("参加します🙌")).to be_nil
    end

    it '既存の日本語・英語エイリアスが引き続き機能すること' do
      {
        "Vo" => "Vocal", "ボーカル" => "Vocal", "ヴォーカル" => "Vocal",
        "Gt" => "Guitar", "ギター" => "Guitar",
        "Guitar(Lead)" => "Guitar", "Guitar(Rhythm)" => "Guitar", "Guitar(Lythm)" => "Guitar",
        "Lead Guitar" => "Guitar", "Rhythm Guitar" => "Guitar",
        "Ba" => "Bass", "ベース" => "Bass",
        "Dr" => "Drums", "ドラム" => "Drums", "ドラムス" => "Drums",
        "Key" => "Keyboard", "キーボード" => "Keyboard"
      }.each do |raw, expected|
        expect(described_class.normalize(raw)).to eq(expected), "#{raw.inspect} は #{expected} になるべき"
      end
    end

    it '正式なNAME_OPTIONSの挙動が変わらないこと' do
      %w[Vocal Guitar Bass Drums Keyboard Other].each do |name|
        expect(described_class.normalize(name)).to eq name
      end
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

  describe '.sql_normalized_name' do
    # ランキング集計は 1 本の SQL で正規化まで行う。SQL の CASE 式が #normalize と
    # 同じ結果を返すことを、実際に MySQL で評価して検証する。
    def sql_normalize(raw)
      connection = ActiveRecord::Base.connection
      expression = described_class.sql_normalized_name(connection.quote(raw))
      connection.select_value("SELECT #{expression}")
    end

    inputs = [
      *JoinPart::NAME_OPTIONS,
      "Vo", "VO", "vo", "ボーカル", "ヴォーカル", "Voca", "Vocai",
      "Gt", "ギター", "Guitar(Lead)", "Guitar(Rhythm)", "Guitar(Lythm)",
      "guitar (lead)", " Guitar(Lythm) ", "Lead Guitar", "Rhythm Guitar",
      "Guiar", "Guigar", "Gutar", "Guitar1", "Guitar2",
      "Ba", "ベース", "Dr", "ドラム", "ドラムス", "Durms",
      "Key", "キーボード", "Keyboad", "Keyborad", "Keyobard",
      "Cho", "Chorus", "コーラス", "Percussion", "Acoustic Guitar",
      "参加します🙌", "guitar", "GUITAR", "", "   "
    ]

    inputs.each do |raw|
      it "#{raw.inspect} を #normalize と同じ結果に正規化すること" do
        expect(sql_normalize(raw)).to eq(described_class.normalize(raw))
      end
    end
  end
end
