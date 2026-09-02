module PerformanceHistory
  # 2025年1月のセレクトボックス化以前、JoinPart.join_part_nameは自由入力だった
  # (JoinPartモデル自体にinclusion validationは無いため、レガシーな自由入力値は
  # 今もDBに残り得る)。演奏実績の動的集計・経験者検索では、別イベントの現行パート
  # (常にJoinPart::NAME_OPTIONSのいずれか)と旧パート名を突合する必要があるため、
  # ここで安全な範囲のみ正規化する。
  #
  # DB上の値は一切書き換えず、検索時の突合(このモジュールの戻り値同士の一致判定)にのみ使う。
  #
  # 意味を一意に決められない値(Cho/Chorus/コーラス/Percussion/Acoustic Guitar等)は、
  # 誤って現行パートへ寄せると経験者検索の精度を損なう(存在しない経験を「あり」と
  # 誤表示してしまう)ため、あえてマッピングしない。マッピングできない値はnilを返し、
  # 呼び出し側で「一致させない」扱いにする。
  #
  # レガシーな自由入力に "Guitar(Lead)" / "Guitar(Lythm)"(Rhythmの綴り誤り)のような
  # 「Lead/Rhythmの区別付きギター」表記が残っている。現行パートに Lead/Rhythm の区別は無く
  # (JoinPart::NAME_OPTIONSは Guitar のみ)、演奏実績・経験者検索は「Guitar系の演奏経験があるか」を
  # 見る用途のため、検索時の突合ではこれらを Guitar として扱う。DB上の値("Lythm"の綴りを含む)は
  # 書き換えない。
  module PartNameNormalizer
    # ユーザーが安全と判断した表記ゆれのみを対象とする。キーは小文字化 + 空白除去して比較するため
    # 大文字小文字の違い(Vo/VO/vo等)・空白ゆれ("Guitar (Lead)"等)は自動的に吸収される。
    SAFE_ALIASES = {
      "vo" => "Vocal",
      "ボーカル" => "Vocal",
      "ヴォーカル" => "Vocal",
      "gt" => "Guitar",
      "ギター" => "Guitar",
      "guitar(lead)" => "Guitar",
      "guitar(rhythm)" => "Guitar",
      "guitar(lythm)" => "Guitar", # "Rhythm" の綴り誤り。既存DB値をそのまま突合するため許容する。
      "leadguitar" => "Guitar",
      "rhythmguitar" => "Guitar",
      "ba" => "Bass",
      "ベース" => "Bass",
      "dr" => "Drums",
      "ドラム" => "Drums",
      "ドラムス" => "Drums",
      "key" => "Keyboard",
      "キーボード" => "Keyboard",

      # 2025年1月のセレクトボックス化以前に自由入力で保存された、明らかな綴り誤り・
      # truncation・連番付き表記。本番データ調査で実在を確認済みで、いずれも現行パートの
      # どれか1つにしか解釈できない(Guitar1/Guitar2は「1人目/2人目のギター」の意で、
      # Lead/Rhythmと同じく現行パートに区別が無いためGuitarへ寄せる)。
      # キーは downcase 後(必要なら空白除去後)に突合されるため、小文字で登録する。
      "durms" => "Drums",
      "guiar" => "Guitar",
      "guigar" => "Guitar",
      "gutar" => "Guitar",
      "guitar1" => "Guitar",
      "guitar2" => "Guitar",
      "guitar(リード)" => "Guitar",
      "guitar(リズム)" => "Guitar",
      "keyboad" => "Keyboard",
      "keyborad" => "Keyboard",
      "keyobard" => "Keyboard",
      "voca" => "Vocal",
      "vocai" => "Vocal"
    }.freeze

    # 戻り値: JoinPart::NAME_OPTIONSのいずれか、またはnil(安全に変換できない値)。
    def self.normalize(raw_name)
      name = raw_name.to_s.strip
      return nil if name.blank?
      # 既に現行の選択肢そのものであれば、それを正とする(最も多いケースの高速パス)。
      return name if JoinPart::NAME_OPTIONS.include?(name)

      key = name.downcase
      SAFE_ALIASES[key] || SAFE_ALIASES[key.gsub(/[[:space:]]+/, "")]
    end

    # #normalize と同じ突合結果を SQL 側で得るための CASE 式(文字列)を返す。
    # ランキング集計(PerformanceRankings::RankingQuery)で 1 本の GROUP BY クエリに
    # まとめるために使う。対応表は #normalize と同じ SAFE_ALIASES / JoinPart::NAME_OPTIONS
    # を参照するため、語彙の増減はこのファイルだけで一元管理される。
    # 突合できない値には NULL を返す(呼び出し側で「集計対象外」として扱う)。
    #
    # SQLite(テスト) / MySQL(本番)の両方で動くよう、移植性のある関数(TRIM / LOWER /
    # REPLACE / CASE)だけを使う。
    #
    # 注記:
    #   - #normalize の高速パスは大文字小文字を区別するが、MySQL の既定 collation は
    #     区別しないため、"vocal" のような小文字だけの英語表記では MySQL 側が
    #     #normalize より緩く一致する可能性がある(実データのパート名にはほぼ存在しない)。
    #   - TRIM は半角スペースのみ、SQLite の LOWER は ASCII のみを小文字化する。
    def self.sql_normalized_name(column_sql)
      connection = ActiveRecord::Base.connection
      trimmed = "TRIM(#{column_sql})"
      lowered = "LOWER(#{trimmed})"
      spaceless = "REPLACE(REPLACE(REPLACE(#{lowered}, ' ', ''), '\t', ''), '　', '')"

      whens = []

      # 高速パス: 既に現行の選択肢そのもの。
      JoinPart::NAME_OPTIONS.each do |name|
        quoted = connection.quote(name)
        whens << "WHEN #{trimmed} = #{quoted} THEN #{quoted}"
      end

      # レガシー別名: 小文字化した値、および空白除去した値のどちらかが一致すれば正規化する。
      SAFE_ALIASES.group_by { |_raw, canonical| canonical }.each do |canonical, pairs|
        keys = pairs.map { |raw, _canonical| connection.quote(raw) }.join(", ")
        quoted_canonical = connection.quote(canonical)
        whens << "WHEN #{lowered} IN (#{keys}) THEN #{quoted_canonical}"
        whens << "WHEN #{spaceless} IN (#{keys}) THEN #{quoted_canonical}"
      end

      "CASE #{whens.join(' ')} ELSE NULL END"
    end
  end
end
