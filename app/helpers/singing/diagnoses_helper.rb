module Singing::DiagnosesHelper
  SCORE_GUIDES = {
    overall: {
      label: "総合",
      description: "音程・リズム・表現のバランスから見た、全体的な安定感の目安です。"
    },
    pitch: {
      label: "音程",
      description: "音の揺れや安定のしやすさを簡易的に見た目安です。"
    },
    rhythm: {
      label: "リズム",
      description: "音の入り方や流れの安定感を簡易的に見た目安です。"
    },
    expression: {
      label: "表現",
      description: "音量変化や抑揚の出し方を簡易的に見た目安です。"
    }
  }.freeze

  SCORE_COMPARISON_LABELS = {
    overall_score: "総合",
    pitch_score: "音程",
    rhythm_score: "リズム",
    expression_score: "表現"
  }.freeze

  COMMON_SCORE_CARD_CONFIGS = {
    "vocal" => [
      { key: :pitch_score, label: "音程", short_label: "Pitch" },
      { key: :rhythm_score, label: "リズム", short_label: "Rhythm" },
      { key: :expression_score, label: "表現", short_label: "Expression" }
    ],
    "guitar" => [
      { key: :pitch_score, label: "ピッチ", short_label: "Pitch" },
      { key: :rhythm_score, label: "リズム", short_label: "Rhythm" },
      { key: :expression_score, label: "表現", short_label: "Expression" }
    ],
    "bass" => [
      { key: :pitch_score, label: "ピッチ", short_label: "Pitch" },
      { key: :rhythm_score, label: "リズム", short_label: "Rhythm" },
      { key: :expression_score, label: "表現", short_label: "Expression" }
    ],
    "drums" => [
      { key: :rhythm_score, label: "リズム", short_label: "Rhythm" },
      { key: :expression_score, label: "表現", short_label: "Expression" }
    ],
    "keyboard" => [
      { key: :pitch_score, label: "ピッチ", short_label: "Pitch" },
      { key: :rhythm_score, label: "リズム", short_label: "Rhythm" },
      { key: :expression_score, label: "表現", short_label: "Expression" }
    ],
    "band" => [
      { key: :pitch_score, label: "調和", short_label: "Harmony" },
      { key: :rhythm_score, label: "リズムの揃い", short_label: "Rhythm" },
      { key: :expression_score, label: "ダイナミクス", short_label: "Dynamics" }
    ]
  }.freeze

  SPECIFIC_SCORE_LABELS = {
    "vocal" => {
      volume_score: "声量",
      pronunciation_score: "発音",
      relax_score: "リラックス",
      mix_voice_score: "ミックスボイス"
    },
    "guitar" => {
      attack_score: "アタック",
      muting_score: "ミュート",
      stability_score: "安定感",
      tone_score: "音色"
    },
    "bass" => {
      groove_score: "グルーヴ",
      note_length_score: "音価",
      stability_score: "安定感",
      tone_score: "音色"
    },
    "drums" => {
      tempo_stability_score: "テンポ安定",
      rhythm_precision_score: "リズム精度",
      dynamics_score: "ダイナミクス",
      fill_control_score: "フィル"
    },
    "keyboard" => {
      chord_stability_score: "コード安定",
      note_connection_score: "音のつながり",
      touch_score: "タッチ",
      harmony_score: "ハーモニー"
    },
    "band" => {
      ensemble_score: "アンサンブル力",
      harmony_score: "調和",
      role_understanding_score: "役割理解",
      volume_balance_score: "音量バランス",
      rhythm_unity_score: "リズムの揃い",
      groove_score: "グルーヴ",
      dynamics_score: "ダイナミクス",
      cohesion_score: "全体のまとまり"
    }
  }.freeze

  SPECIFIC_SCORE_SECTION_DESCRIPTIONS = {
    "vocal" => "声量・発音・リラックス・ミックスボイスなど、ボーカルならではの補足スコアです。共通スコアとあわせて、次に意識するポイントの目安としてご確認ください。",
    "guitar" => "アタック・ミュート・安定感など、ギター演奏ならではの補足スコアです。音の立ち上がりや不要な残響、演奏のまとまりを振り返る目安としてご確認ください。",
    "bass" => "グルーヴ・音価・安定感など、ベース演奏ならではの補足スコアです。曲を支えるリズムのまとまりや音の長さ、演奏の安定を振り返る目安としてご確認ください。",
    "drums" => "テンポ安定・リズム精度・ダイナミクス・フィルなど、ドラム演奏ならではの補足スコアです。ビートの揃い方や強弱、展開のまとまりを振り返る目安としてご確認ください。",
    "keyboard" => "コード安定・音のつながり・タッチ・ハーモニーなど、キーボード演奏ならではの補足スコアです。和音のまとまりや音のつながり、打鍵ニュアンスを振り返る目安としてご確認ください。",
    "band" => "アンサンブル力・調和・役割理解・音量バランス・リズムの揃い・グルーヴ・ダイナミクス・全体のまとまりなど、バンド演奏ならではの補足スコアです。各パートの噛み合い方やバンド全体のまとまりを振り返る目安としてご確認ください。"
  }.freeze

  BAND_ENSEMBLE_SCORE_CONFIGS = [
    {
      key: :balance,
      label: "音量バランス",
      source_keys: %i[balance_score volume_balance_score balance],
      description: "各パートの音量が極端に偏らず、全体として聴きやすい状態かを見ています。"
    },
    {
      key: :tightness,
      label: "リズムの揃い",
      source_keys: %i[tightness_score rhythm_unity_score tightness],
      description: "ドラム・ベース・伴奏・歌のタイミングがまとまっているかを見ています。"
    },
    {
      key: :groove,
      label: "グルーヴ",
      source_keys: %i[groove_score groove],
      description: "演奏全体に自然なノリや推進力があるかを見ています。"
    },
    {
      key: :role_clarity,
      label: "役割理解",
      source_keys: %i[role_clarity_score role_understanding_score role_clarity],
      description: "各パートが自分の役割を邪魔せず、音域や立ち位置を作れているかを見ています。"
    },
    {
      key: :dynamics,
      label: "抑揚・展開",
      source_keys: %i[dynamics_score dynamics],
      description: "Aメロ・サビ・間奏などで、曲の展開に合わせた抑揚があるかを見ています。"
    },
    {
      key: :cohesion,
      label: "一体感",
      source_keys: %i[cohesion_score ensemble_score cohesion],
      description: "バンド全体として一つの演奏にまとまって聴こえるかを見ています。"
    }
  ].freeze

  ADVANCED_FEEDBACK_TARGETS = {
    pitch: {
      label: "音程",
      score_key: :pitch_score,
      title: "音程の読み解き",
      high: {
        summary: "狙った音に対して、声の位置を保ちやすい状態です。",
        strength: "音の安定感があることで、フレーズ全体に余裕が出やすくなっています。",
        next_step: "語尾やロングトーンの終わり際まで同じ響きを保てるかを確認すると、さらに安定感を伸ばしやすくなります。"
      },
      middle: {
        summary: "音程の土台は見えていますが、部分的に揺れやすいポイントがありそうです。",
        strength: "大きく崩れずに歌えているため、短いフレーズ単位で整える練習と相性がよい状態です。",
        next_step: "出だしと語尾を録音で確認し、狙った音に無理なく戻れる感覚を少しずつ育てていきましょう。"
      },
      low: {
        summary: "まずは狙った音に対して、無理なく安定する感覚を育てる余地があります。",
        strength: "伸びしろが見えやすい状態なので、練習した変化を次回診断で確認しやすい領域です。",
        next_step: "出しやすい高さでロングトーンを行い、声が揺れにくい息の量と響きを探すところから始めましょう。"
      }
    },
    rhythm: {
      label: "リズム",
      score_key: :rhythm_score,
      title: "リズムの読み解き",
      high: {
        summary: "拍の流れに乗りやすく、歌い出しやフレーズの入りが安定しやすい状態です。",
        strength: "リズムの安定があることで、表現や言葉のニュアンスに意識を向けやすくなっています。",
        next_step: "あえて少し弱く歌う箇所でもテンポが崩れないかを確認すると、表現の幅を広げやすくなります。"
      },
      middle: {
        summary: "リズムの流れはつかめていますが、入りや語尾で少し前後しやすい可能性があります。",
        strength: "大枠のテンポ感はあるため、細かなタイミングを整えるだけで聴こえ方が変わりやすい状態です。",
        next_step: "メトロノームや原曲に合わせて、歌い始めの子音と語尾の切り方をそろえてみましょう。"
      },
      low: {
        summary: "拍の取り方やフレーズの入りに、まだ整えられる余地があります。",
        strength: "リズムは短い範囲で反復しやすく、練習の手応えが出やすいポイントです。",
        next_step: "まずはサビやAメロの一部だけを選び、手拍子やメトロノームに合わせて歌い出しをそろえましょう。"
      }
    },
    expression: {
      label: "表現",
      score_key: :expression_score,
      title: "表現の読み解き",
      high: {
        summary: "声の強弱や抑揚が出ていて、曲の雰囲気を伝えやすい状態です。",
        strength: "表現の幅があることで、聴き手にフレーズの流れや感情が届きやすくなっています。",
        next_step: "良く出ている抑揚を保ちながら、静かな箇所でも言葉がぼやけないかを確認してみましょう。"
      },
      middle: {
        summary: "表現のきっかけは見えていますが、強弱や語尾のニュアンスをさらに足せそうです。",
        strength: "歌の土台があるため、フレーズごとの意図を決めるだけでも印象が変わりやすい状態です。",
        next_step: "サビ前後で声量を少し変えたり、伝えたい言葉だけを丁寧に置いたりして変化をつけてみましょう。"
      },
      low: {
        summary: "まずは声の大きさや言葉の置き方に、少しずつ変化をつける余地があります。",
        strength: "表現は小さな変化から始められるため、無理に大きく歌わなくても改善の入口を作れます。",
        next_step: "一番伝えたい一行を選び、そこだけ少し強く・長く・丁寧に歌う練習から始めましょう。"
      }
    }
  }.freeze

  GUITAR_ADVANCED_FEEDBACK_TARGETS = {
    attack: {
      label: "アタック",
      score_key: :attack_score,
      title: "アタックの読み解き",
      high: {
        summary: "音の立ち上がりがはっきりしていて、フレーズの輪郭が伝わりやすい状態です。",
        strength: "ピッキングの入りが見えやすく、リズムやフレーズの意図が聴き手に届きやすくなっています。",
        next_step: "強く弾く箇所だけでなく、弱めに弾く箇所でも音の出だしがそろうかを確認すると、表現の幅を広げやすくなります。"
      },
      middle: {
        summary: "音の立ち上がりの土台はありますが、フレーズによって粒の出方に少し差が出やすい状態です。",
        strength: "大きく崩れずに弾けているため、入りのタイミングやピッキングの角度を整えるだけで印象が変わりやすいです。",
        next_step: "短いフレーズをゆっくり弾き、最初の1音とアクセントの音だけを録音で確認してみましょう。"
      },
      low: {
        summary: "まずは音の出だしをそろえることで、フレーズの輪郭を作りやすくなる余地があります。",
        strength: "改善ポイントが分かりやすい領域なので、ピッキングの位置や入りのタイミングを少し変えるだけでも変化を確認しやすいです。",
        next_step: "開放弦や簡単な単音フレーズで、同じ強さ・同じタイミングで音を出す練習から始めましょう。"
      }
    },
    muting: {
      label: "ミュート",
      score_key: :muting_score,
      title: "ミュートの読み解き",
      high: {
        summary: "不要な残響をコントロールしやすく、鳴らしたい音が整理されて聴こえやすい状態です。",
        strength: "音の切り方が安定すると、リズムのキレやフレーズの見通しが良くなります。",
        next_step: "休符や音を止める箇所でも余韻が長く残りすぎないかを確認すると、さらにまとまりを出しやすくなります。"
      },
      middle: {
        summary: "ミュートの意識は見えていますが、音を止める場所や不要弦の処理に少しばらつきが出る可能性があります。",
        strength: "鳴らしたい音は見えているため、右手と左手の触れ方を整えるとフレーズがすっきりしやすいです。",
        next_step: "コードやリフを短く区切り、鳴らす音と止める音を分けて録音で確認してみましょう。"
      },
      low: {
        summary: "不要な残響や鳴らしたくない弦を整理すると、演奏全体が聴き取りやすくなる余地があります。",
        strength: "ミュートは短い反復で手応えを作りやすく、練習した変化を次回診断で確認しやすい項目です。",
        next_step: "まずは2〜3音の短いパターンで、弾いた後に音を止める動きをゆっくり確認しましょう。"
      }
    },
    stability: {
      label: "安定感",
      score_key: :stability_score,
      title: "安定感の読み解き",
      high: {
        summary: "音量やタイミングのまとまりがあり、演奏全体が安定して聴こえやすい状態です。",
        strength: "安定感があることで、曲の流れを支えながら細かなニュアンスにも意識を向けやすくなっています。",
        next_step: "同じフレーズを数回録音し、良かったテイクの弾き方を再現できるかを確認すると、強みを定着させやすいです。"
      },
      middle: {
        summary: "演奏のまとまりは見えていますが、音量やタイミングに少し揺れが出る箇所がありそうです。",
        strength: "土台はあるため、テンポを少し落として反復すると安定感を積み上げやすい状態です。",
        next_step: "メトロノームに合わせて、同じフレーズを3回続けても音量とタイミングが近いかを確認してみましょう。"
      },
      low: {
        summary: "まずは音量やタイミングのばらつきを小さくすると、演奏のまとまりを作りやすくなります。",
        strength: "安定感は基礎練習の効果が出やすく、短い範囲に絞るほど変化を感じやすい項目です。",
        next_step: "難しい箇所を一度短く切り出し、ゆっくりのテンポで音量とタイミングをそろえる練習から始めましょう。"
      }
    },
    cohesion: {
      label: "全体のまとまり",
      score_key: :overall_score,
      title: "全体のまとまり",
      high: {
        summary: "アタック、リズム、音の整理がつながり、演奏全体としてまとまりが出やすい状態です。",
        strength: "曲の流れを保ちながら弾けているため、聴き手にフレーズの方向性が伝わりやすくなっています。",
        next_step: "強みを保ちながら、音を伸ばす箇所と切る箇所の差を少し大きくすると、さらに立体感を出しやすくなります。"
      },
      middle: {
        summary: "演奏全体の土台は見えています。細かな粒立ちや音の切り方をそろえると、よりまとまりが出そうです。",
        strength: "大きな方向性はつかめているため、部分ごとの確認で完成度を上げやすい状態です。",
        next_step: "1曲全体ではなく、気になる4小節だけを選んで、アタック・ミュート・安定感を順番に確認してみましょう。"
      },
      low: {
        summary: "演奏全体を整えるために、まずは短い範囲で音の入り方と止め方をそろえる余地があります。",
        strength: "伸ばすポイントを絞りやすい状態なので、短い練習でも次回の変化を感じやすいです。",
        next_step: "テンポを落とし、2〜4小節だけを録音して、音の出だし・余韻・タイミングをひとつずつ確認しましょう。"
      }
    }
  }.freeze

  BASS_ADVANCED_FEEDBACK_TARGETS = {
    groove: {
      label: "グルーヴ",
      score_key: :groove_score,
      title: "グルーヴの読み解き",
      high: {
        summary: "リズムの土台として気持ちよく前へ進む流れがあり、低音が曲全体を支えやすい状態です。",
        strength: "ノリの軸が見えやすく、ドラムや伴奏と合わさったときにも安定した推進力を作りやすくなっています。",
        next_step: "良く乗れている拍の感じを保ちながら、休符前後でも入りが揺れないかを録音で確認すると、さらにまとまりを出しやすくなります。"
      },
      middle: {
        summary: "グルーヴの土台はあります。音の入りと拍の揺れをもう少しそろえると、ベースライン全体がまとまりやすくなります。",
        strength: "大きく流れを外していないため、短い反復でノリの気持ちよさを育てやすい状態です。",
        next_step: "ドラムのキックやメトロノームに合わせ、同じフレーズを数回弾いて入りの位置をそろえてみましょう。"
      },
      low: {
        summary: "まずは拍の感じ方と音の入りを整えることで、ベースの説得力を上げやすい余地があります。",
        strength: "グルーヴは短い範囲で確認しやすく、練習した変化を次回診断で感じやすい項目です。",
        next_step: "2小節ほどの短いパターンを選び、拍の頭と音の出だしが近づくようにゆっくり確認しましょう。"
      }
    },
    note_length: {
      label: "音価",
      score_key: :note_length_score,
      title: "音価の読み解き",
      high: {
        summary: "音の長さや切れ際がそろいやすく、ベースラインの輪郭が整理されて聴こえやすい状態です。",
        strength: "伸ばす音と止める音の差が出ることで、リズムの気持ちよさやフレーズの意図が伝わりやすくなっています。",
        next_step: "今のまとまりを保ちながら、休符や短く切る音でも余韻が長く残りすぎないかを確認してみましょう。"
      },
      middle: {
        summary: "音価の意識は見えていますが、フレーズによって音の長さや切れ際に少しばらつきが出やすい状態です。",
        strength: "音を伸ばす・止める感覚の土台はあるため、狙う長さを決めるだけで聴こえ方が変わりやすいです。",
        next_step: "同じ音型を短め・長めで弾き分けて録音し、曲に合う音の長さを探してみましょう。"
      },
      low: {
        summary: "音の長さや切れ際をそろえると、低音の支えがよりはっきり伝わりやすくなります。",
        strength: "音価はゆっくり確認しやすい項目なので、テンポを落とすほど改善の手応えを作りやすいです。",
        next_step: "まずは1音ずつ、鳴らす長さと止めるタイミングを決めてから短いパターンに戻してみましょう。"
      }
    },
    stability: {
      label: "安定感",
      score_key: :stability_score,
      title: "安定感の読み解き",
      high: {
        summary: "音量やタイミングのまとまりがあり、低音の支えが安定して聴こえやすい状態です。",
        strength: "ベースの安定感があることで、曲全体の土台が見えやすく、他のパートも乗りやすくなります。",
        next_step: "強みを保ちながら、静かな箇所や音数が少ない箇所でも同じ安定感を再現できるか確認しましょう。"
      },
      middle: {
        summary: "演奏のまとまりは見えていますが、音量やタイミングに少し揺れが出る箇所がありそうです。",
        strength: "土台はあるため、テンポを少し落として反復すると低音の支えをさらに整えやすい状態です。",
        next_step: "同じフレーズを3回録音し、音量とタイミングの差が少ないテイクを探して再現してみましょう。"
      },
      low: {
        summary: "まずは音量やタイミングのばらつきを小さくすると、ベースラインの支えが作りやすくなります。",
        strength: "安定感は短い基礎練習の効果が出やすく、練習前後の変化を確認しやすい項目です。",
        next_step: "難しいフレーズを短く切り出し、ゆっくりのテンポで音量と入りをそろえる練習から始めましょう。"
      }
    },
    cohesion: {
      label: "全体のまとまり",
      score_key: :overall_score,
      title: "全体のまとまり",
      high: {
        summary: "グルーヴ、音価、安定感がつながり、曲全体を支えるベースラインとしてまとまりが出やすい状態です。",
        strength: "低音の流れが安定していることで、フレーズの役割や曲の進み方が聴き手に伝わりやすくなっています。",
        next_step: "今のまとまりを保ちながら、サビや展開部分で音の長さや強弱を少し変えると表現の幅を広げやすくなります。"
      },
      middle: {
        summary: "ベースライン全体の土台は見えています。細かな入りや音価をそろえると、より曲を支える感覚が出そうです。",
        strength: "大きな方向性はつかめているため、部分ごとの確認で完成度を上げやすい状態です。",
        next_step: "気になる2〜4小節だけを選び、グルーヴ・音価・安定感を順番に録音で確認してみましょう。"
      },
      low: {
        summary: "演奏全体を整えるために、まずは短い範囲で音の入り方と長さをそろえる余地があります。",
        strength: "伸ばすポイントを絞りやすい状態なので、短い練習でも次回の変化を感じやすいです。",
        next_step: "テンポを落とし、2小節だけを録音して、拍の入り・音の長さ・音量をひとつずつ確認しましょう。"
      }
    }
  }.freeze

  DRUMS_ADVANCED_FEEDBACK_TARGETS = {
    tempo_stability: {
      label: "テンポ安定",
      score_key: :tempo_stability_score,
      title: "テンポ安定の読み解き",
      high: {
        summary: "ビートの土台が安定していて、演奏全体を安心して支えやすい状態です。",
        strength: "一定のテンポ感があることで、フレーズや展開が前に進みやすく、聴き手にも流れが伝わりやすくなっています。",
        next_step: "今の安定感を保ちながら、静かな箇所やフィル前後でもクリックとの距離感が変わりすぎないかを確認してみましょう。"
      },
      middle: {
        summary: "大きく崩れてはいませんが、一定の流れをもう少しそろえると演奏全体がまとまりやすい状態です。",
        strength: "テンポの土台は見えているため、短い範囲で反復すると安定感を積み上げやすいです。",
        next_step: "8小節だけを選び、クリックに合わせて拍の頭が前後しすぎないか録音で確認してみましょう。"
      },
      low: {
        summary: "まずは一定のテンポ感を保つ意識を持つと、演奏の説得力が上がりやすい余地があります。",
        strength: "テンポは練習前後の変化を確認しやすく、短いパターンでも改善の手応えを作りやすい項目です。",
        next_step: "ゆっくりめのテンポで、ハイハットやスネアなど1つのパートだけに絞って拍の位置を整えましょう。"
      }
    },
    rhythm_precision: {
      label: "リズム精度",
      score_key: :rhythm_precision_score,
      title: "リズム精度の読み解き",
      high: {
        summary: "叩きのタイミングや粒がそろいやすく、ビートの輪郭がはっきり伝わる状態です。",
        strength: "音の入りが整理されているため、曲のノリやフレーズの切り替わりが聴き取りやすくなっています。",
        next_step: "強く叩く音だけでなく、弱めに置く音でもタイミングがそろうかを確認すると、さらに安定したグルーヴにつながります。"
      },
      middle: {
        summary: "リズムの流れはつかめていますが、叩きの粒や入りに少しばらつきが出る可能性があります。",
        strength: "大枠のノリは見えているため、パートを絞って確認すると精度を上げやすい状態です。",
        next_step: "スネアだけ、ハイハットだけなど音を限定し、同じ間隔で鳴らせているかをゆっくり確認してみましょう。"
      },
      low: {
        summary: "叩きの入りや粒をそろえることで、ビートの説得力を作りやすくなる余地があります。",
        strength: "リズム精度は短い反復で整えやすく、練習した変化が録音でも確認しやすい項目です。",
        next_step: "まずは2小節の基本パターンだけを選び、音数を減らしてタイミングをそろえる練習から始めましょう。"
      }
    },
    dynamics: {
      label: "ダイナミクス",
      score_key: :dynamics_score,
      title: "ダイナミクスの読み解き",
      high: {
        summary: "強弱の出し方に幅があり、曲の展開や勢いを表現しやすい状態です。",
        strength: "音量差が自然に出ることで、同じビートでも平坦になりにくく、演奏に立体感が生まれやすくなっています。",
        next_step: "今の強弱を保ちながら、サビ前やフィル後など展開部分で音量が急に飛びすぎないかを確認してみましょう。"
      },
      middle: {
        summary: "強弱のきっかけは見えていますが、もう少し意図的に差をつけると曲の流れが伝わりやすくなります。",
        strength: "音量の土台はあるため、アクセントを置く場所を決めるだけでも印象を変えやすい状態です。",
        next_step: "同じパターンを小さめ・普通・大きめで叩き分け、曲に合う強弱の幅を録音で探してみましょう。"
      },
      low: {
        summary: "まずは強く出す音と抑える音を分けることで、ビートに表情を作りやすくなります。",
        strength: "ダイナミクスは小さな変化から始められるため、無理に大きく叩かなくても改善の入口を作れます。",
        next_step: "ハイハットを少し抑え、スネアやキックの置き方を確認するなど、1つずつ強弱の役割を分けてみましょう。"
      }
    },
    fill_control: {
      label: "フィルコントロール",
      score_key: :fill_control_score,
      title: "フィルコントロールの読み解き",
      high: {
        summary: "フィルや展開の動きがまとまりやすく、ビートへ戻る流れも自然に作りやすい状態です。",
        strength: "フィル後の着地が見えやすいと、曲の区切りや盛り上がりが聴き手に伝わりやすくなります。",
        next_step: "今のまとまりを保ちながら、フィルの最後の1音から次の1拍目へ自然につながるかを確認してみましょう。"
      },
      middle: {
        summary: "フィルの流れは見えていますが、展開後の着地や音数のまとまりに少し整えられる余地があります。",
        strength: "大きく流れを外していないため、短いフィルを決めて反復すると完成度を上げやすい状態です。",
        next_step: "1つの短いフィルを選び、フィル前のビート、フィル、戻りの1拍目までをセットで録音してみましょう。"
      },
      low: {
        summary: "まずはフィルの音数や戻り方を整理すると、曲の流れが途切れにくくなる余地があります。",
        strength: "フィルは範囲を短くすると練習しやすく、戻りの安定だけでも印象が大きく変わりやすい項目です。",
        next_step: "音数を減らした短いフィルから始め、最後の音を叩いた後に1拍目へ落ち着いて戻る練習をしましょう。"
      }
    },
    cohesion: {
      label: "全体のまとまり",
      score_key: :overall_score,
      title: "全体のまとまり",
      high: {
        summary: "テンポ、リズム、強弱、展開がつながり、演奏全体として前に進む推進力が出やすい状態です。",
        strength: "ビートの軸が見えやすいことで、曲の流れを保ちながら細かな表現にも意識を向けやすくなっています。",
        next_step: "強みを保ちながら、静かな箇所や展開部分でも同じまとまりを再現できるか確認してみましょう。"
      },
      middle: {
        summary: "演奏全体の土台は見えています。テンポ感と叩きの粒をそろえると、さらにまとまりが出そうです。",
        strength: "大きな方向性はつかめているため、部分ごとの確認で完成度を上げやすい状態です。",
        next_step: "気になる4小節だけを選び、テンポ安定・リズム精度・ダイナミクスを順番に録音で確認してみましょう。"
      },
      low: {
        summary: "演奏全体を整えるために、まずは短い範囲でテンポと叩きの入りをそろえる余地があります。",
        strength: "伸ばすポイントを絞りやすい状態なので、短い練習でも次回の変化を感じやすいです。",
        next_step: "テンポを落とし、2〜4小節だけを録音して、拍の位置・強弱・フィル後の戻りをひとつずつ確認しましょう。"
      }
    }
  }.freeze

  KEYBOARD_ADVANCED_FEEDBACK_TARGETS = {
    chord_stability: {
      label: "コード安定",
      score_key: :chord_stability_score,
      title: "和音の安定の読み解き",
      high: {
        summary: "和音のまとまりがあり、演奏全体に安心感が出やすい状態です。",
        strength: "響きが整理されていることで、メロディや伴奏の流れが自然に伝わりやすくなっています。",
        next_step: "今の安定感を保ちながら、コードチェンジ直後の響きが急に揺れないかを録音で確認してみましょう。"
      },
      middle: {
        summary: "和音の土台はあります。押さえの安定感や響きの揃いを意識すると、さらにまとまりやすい状態です。",
        strength: "大きく崩れていないため、コードごとの響きを少し整えるだけでも聴こえ方が変わりやすいです。",
        next_step: "よく使うコード進行をゆっくり弾き、切り替えた瞬間の音の重なりが自然か確認してみましょう。"
      },
      low: {
        summary: "まずは和音のまとまりを意識して、音のぶつかりや揺れを減らすと聴こえ方が整いやすくなります。",
        strength: "和音は短い進行で反復しやすく、練習した変化を次回診断でも確認しやすい項目です。",
        next_step: "2つのコードだけを選び、ひとつずつ響きを聴きながら、音が濁りすぎない押さえ方や打鍵を探してみましょう。"
      }
    },
    note_connection: {
      label: "音のつながり",
      score_key: :note_connection_score,
      title: "音のつながりの読み解き",
      high: {
        summary: "音と音の流れが自然につながり、フレーズがなめらかに聴こえやすい状態です。",
        strength: "途切れ方が少ないことで、伴奏にもメロディにもまとまりが出やすく、曲の流れを保ちやすくなっています。",
        next_step: "なめらかさを保ちながら、あえて短く切る箇所との違いを作ると、表現の幅を広げやすくなります。"
      },
      middle: {
        summary: "音のつながりは見えていますが、箇所によって少し途切れたり重なりすぎたりする可能性があります。",
        strength: "流れの土台はあるため、指の移動やペダルの使い方を少し整えるだけで印象が変わりやすい状態です。",
        next_step: "短いフレーズをゆっくり弾き、音が切れる場所と重なりすぎる場所を録音で確認してみましょう。"
      },
      low: {
        summary: "音のつながりを整えることで、フレーズの流れや演奏の彩りが伝わりやすくなる余地があります。",
        strength: "つながりはテンポを落とすほど確認しやすく、少しずつ自然な流れを作りやすい項目です。",
        next_step: "まずは2小節ほどに絞り、前の音が消えるタイミングと次の音の入りをゆっくりそろえてみましょう。"
      }
    },
    touch: {
      label: "タッチ",
      score_key: :touch_score,
      title: "タッチの読み解き",
      high: {
        summary: "打鍵の揃いがあり、音の強さやニュアンスが安定して伝わりやすい状態です。",
        strength: "タッチが整うことで、同じフレーズでも響きの自然さや演奏全体の彩りが出やすくなっています。",
        next_step: "今の揃いを保ちながら、弱く弾く箇所でも音の芯が薄くなりすぎないかを確認してみましょう。"
      },
      middle: {
        summary: "タッチの土台はありますが、音の強さや打鍵の揃いに少しばらつきが出る箇所がありそうです。",
        strength: "演奏の方向性は見えているため、強く弾く音と支える音を分けるだけでも聴こえ方が整いやすいです。",
        next_step: "同じフレーズを小さめ・普通・少し大きめで弾き分け、打鍵の強さが急に跳ねないか録音で確認しましょう。"
      },
      low: {
        summary: "まずは打鍵の強さや音の入りをそろえると、演奏全体の聴こえ方が安定しやすくなります。",
        strength: "タッチは短い範囲で確認しやすく、指先の感覚を整えるほど変化を感じやすい項目です。",
        next_step: "ゆっくりのテンポで1音ずつ弾き、同じ音量と同じ入り方になるように打鍵を整える練習から始めましょう。"
      }
    },
    harmony: {
      label: "ハーモニー",
      score_key: :harmony_score,
      title: "ハーモニーの読み解き",
      high: {
        summary: "響きの自然さがあり、ハーモニーの安定感が演奏全体を支えやすい状態です。",
        strength: "音の重なりが心地よくまとまることで、曲の雰囲気や彩りが聴き手に届きやすくなっています。",
        next_step: "今のまとまりを保ちながら、展開部分で響きが濁りすぎないかを確認すると、さらに表情を作りやすくなります。"
      },
      middle: {
        summary: "ハーモニーの方向性は見えています。響きの濁りや音量バランスを整えると、より自然に聴こえやすい状態です。",
        strength: "和音や音の重なりを活かせているため、部分ごとの響きを確認することで完成度を上げやすいです。",
        next_step: "気になるコードだけを取り出し、上の音と下の音のバランスが曲に合っているか録音で聴いてみましょう。"
      },
      low: {
        summary: "音の重なりや響きの自然さを整えると、演奏全体の彩りが伝わりやすくなる余地があります。",
        strength: "ハーモニーはゆっくり確認しやすく、響きを聴く習慣がそのまま演奏の安定につながりやすい項目です。",
        next_step: "まずは1つのコードを長めに鳴らし、強すぎる音や埋もれる音がないかを確認してから短い進行に戻してみましょう。"
      }
    },
    cohesion: {
      label: "全体のまとまり",
      score_key: :overall_score,
      title: "全体のまとまり",
      high: {
        summary: "和音、音のつながり、タッチ、響きがつながり、演奏全体として自然なまとまりが出やすい状態です。",
        strength: "伴奏やメロディの役割が見えやすく、曲の雰囲気を保ちながら演奏を進めやすくなっています。",
        next_step: "強みを保ちながら、静かな箇所と盛り上がる箇所で響きの色を少し変えると、表現の幅を広げやすくなります。"
      },
      middle: {
        summary: "演奏全体の土台は見えています。音のつながりやタッチをそろえると、さらにまとまりが出そうです。",
        strength: "大きな方向性はつかめているため、短い範囲で響きや打鍵を確認すると完成度を上げやすい状態です。",
        next_step: "気になる4小節だけを選び、和音の安定・音のつながり・タッチを順番に録音で確認してみましょう。"
      },
      low: {
        summary: "演奏全体を整えるために、まずは短い範囲で響きと打鍵の揃いを作る余地があります。",
        strength: "伸ばすポイントを絞りやすい状態なので、短い練習でも次回の変化を感じやすいです。",
        next_step: "テンポを落とし、2〜4小節だけを録音して、和音の響き・音のつながり・打鍵の強さをひとつずつ確認しましょう。"
      }
    }
  }.freeze

  BAND_ADVANCED_FEEDBACK_TARGETS = {
    ensemble: {
      label: "アンサンブル力",
      score_key: :ensemble_score,
      title: "アンサンブルの読み解き",
      high: {
        summary: "各パートの入り方や重なりが自然で、バンドとしてまとまりやすい状態です。",
        strength: "噛み合いが見えているため、個々の演奏が前に出ても全体像を崩しにくくなっています。",
        next_step: "今の噛み合いを保ちながら、セクション切り替えでも同じまとまりを再現できるか確認してみましょう。"
      },
      middle: {
        summary: "アンサンブルの土台はあります。入りのタイミングや重なり方を少しそろえると、まとまりが増しやすい状態です。",
        strength: "大きく崩れていないため、短い区間で合わせ方を確認するだけでも変化が出やすいです。",
        next_step: "気になる4〜8小節を選び、誰が前に出る場面かをそろえて録音を聴き返してみましょう。"
      },
      low: {
        summary: "まずは各パートの入り方と重なり方をそろえることで、バンド全体の説得力を上げやすくなります。",
        strength: "改善ポイントを共有しやすい状態なので、合わせ練習の手応えを作りやすい領域です。",
        next_step: "短い区間に絞り、クリックやドラムを基準に全員の入りをそろえるところから始めましょう。"
      }
    },
    role_understanding: {
      label: "役割理解",
      score_key: :role_understanding_score,
      title: "役割理解の読み解き",
      high: {
        summary: "各パートの役割分担が見えやすく、支える場面と出る場面の整理ができている状態です。",
        strength: "役割が明確なので、バンド全体の音像に余裕が生まれやすくなっています。",
        next_step: "今の良さを保ちながら、サビやブレイクで役割が入れ替わる場面も確認するとさらに安定しやすいです。"
      },
      middle: {
        summary: "役割の方向性はありますが、同時に前へ出る音が重なる箇所を整理するとまとまりやすい状態です。",
        strength: "各パートの良さは見えているので、住み分けを少し整えるだけでも印象が変わりやすいです。",
        next_step: "セクションごとに主役と支え役を一度言語化して、録音と照らし合わせてみましょう。"
      },
      low: {
        summary: "まずは誰が主役で誰が支えるかを共有すると、バンド全体の見通しを作りやすくなります。",
        strength: "話し合いと短い合わせだけでも変化が出やすく、改善の入口を作りやすい項目です。",
        next_step: "Aメロやサビを1つ選び、各パートが何を優先するかを決めてから再度合わせてみましょう。"
      }
    },
    volume_balance: {
      label: "音量バランス",
      score_key: :volume_balance_score,
      title: "音量バランスの読み解き",
      high: {
        summary: "出過ぎる音と埋もれる音の差が少なく、聴きやすいバランスを作りやすい状態です。",
        strength: "音量の住み分けがあることで、フレーズや展開が自然に伝わりやすくなっています。",
        next_step: "会場や録音環境が変わっても同じ印象になるかを確認すると、再現性を高めやすいです。"
      },
      middle: {
        summary: "大きく崩れてはいませんが、場面によって出過ぎる音や埋もれる音を少し整えたい状態です。",
        strength: "土台はあるため、パートごとの音量を少し引き算するだけでもまとまりやすくなります。",
        next_step: "同じフレーズを録音して、主役の音が自然に聴こえる音量差を探してみましょう。"
      },
      low: {
        summary: "まずは各パートの音量差を見直すことで、アンサンブル全体をかなり聴き取りやすくしやすい状態です。",
        strength: "調整の効果がそのまま録音に出やすく、改善の手応えを共有しやすい項目です。",
        next_step: "全員で一段小さめに合わせ、必要なパートだけを少しずつ足していく形でバランスを探しましょう。"
      }
    },
    groove: {
      label: "グルーヴ",
      score_key: :groove_score,
      title: "グルーヴの読み解き",
      high: {
        summary: "ノリの方向がそろっていて、バンド全体が気持ちよく前へ進みやすい状態です。",
        strength: "同じ拍感を共有できているため、演奏に推進力が出やすくなっています。",
        next_step: "良いノリを保ちながら、静かな場面や展開後でも同じ重心を保てるか確認してみましょう。"
      },
      middle: {
        summary: "グルーヴの土台はあります。前ノリ・後ノリの感覚を少し共有するとさらにまとまりやすい状態です。",
        strength: "大枠の流れは見えているため、リズム隊と伴奏の感じ方をそろえるだけでも変化が出やすいです。",
        next_step: "短い区間を選び、拍の頭を少し前に置くのか後ろに置くのかを全員で合わせてみましょう。"
      },
      low: {
        summary: "まずは拍の感じ方を共有すると、バンド全体のノリを作りやすくなります。",
        strength: "クリックや簡単なループで確認しやすく、合わせ練習の成果を出しやすい項目です。",
        next_step: "ベースとドラムを軸にして、ほかのパートがどこに乗るかを短い区間で合わせ直してみましょう。"
      }
    },
    dynamics: {
      label: "ダイナミクス",
      score_key: :dynamics_score,
      title: "ダイナミクスの読み解き",
      high: {
        summary: "強弱のつけ方に意図があり、曲の展開や盛り上がりを自然に伝えやすい状態です。",
        strength: "全員で抑える場面と押し出す場面が共有できていて、バンド全体に立体感が出やすくなっています。",
        next_step: "今の差を保ちながら、サビ前やブレイク後の音量変化が急になりすぎないかを確認してみましょう。"
      },
      middle: {
        summary: "強弱の方向性はありますが、場面ごとの差をもう少しそろえると展開が伝わりやすい状態です。",
        strength: "曲の構成は見えているので、出す場面と引く場面を決めるだけでも印象が変わりやすいです。",
        next_step: "Aメロ・Bメロ・サビで音量の目安を一度共有してから録音してみましょう。"
      },
      low: {
        summary: "まずはどこで抑えてどこで広げるかをそろえることで、曲全体の表情を作りやすくなります。",
        strength: "小さな変化からでもまとまりが出やすく、合わせ練習で改善を感じやすい項目です。",
        next_step: "1曲通しではなく、サビ前後だけで強弱の差を決めて反復してみましょう。"
      }
    },
    cohesion: {
      label: "全体のまとまり",
      score_key: :cohesion_score,
      title: "全体のまとまり",
      high: {
        summary: "調和、リズム、ノリ、音量差がつながり、バンド全体として一体感が出やすい状態です。",
        strength: "各パートの良さを活かしながら、曲としてひとつに聴こえやすくなっています。",
        next_step: "強みを保ちながら、展開の切り替わりや終わり際でも同じまとまりを再現できるか確認してみましょう。"
      },
      middle: {
        summary: "バンド全体の土台は見えています。役割や音量差、リズムの揃いを少し整えるとさらにまとまりが出そうです。",
        strength: "方向性はつかめているため、短い区間で確認すると完成度を上げやすい状態です。",
        next_step: "気になる8小節だけを録音し、噛み合い・音量差・ノリを順番に見直してみましょう。"
      },
      low: {
        summary: "全体を整えるために、まずは合わせる基準をひとつ決めて共有する余地があります。",
        strength: "改善点をメンバーで共有しやすく、短い修正でも印象が変わりやすい状態です。",
        next_step: "クリック、ドラム、歌メロのどれを軸にするかを決めて、短い区間から合わせ直してみましょう。"
      }
    }
  }.freeze

  PREMIUM_VOICE_TYPE_PROFILES = {
    powerful: {
      title: "パワフルボイス",
      examples: "B'z、MISIA、Superfly",
      description: "声量や響きの存在感が出やすい、力強い歌声タイプです。声の押し出しが魅力になりやすく、サビや盛り上がるフレーズで聴き手を引き込みやすい傾向があります。"
    },
    high_tone: {
      title: "ハイトーンボイス",
      examples: "X JAPAN、YOASOBI",
      description: "高音域の伸びや明るさが魅力になりやすい歌声タイプです。音程の安定や声帯のテンションを整えるほど、伸びやかな響きがより伝わりやすくなります。"
    },
    crystal: {
      title: "クリスタルボイス",
      examples: "徳永英明、宇多田ヒカル",
      description: "透明感ややわらかい響きが印象に残りやすい歌声タイプです。息の流れや発音の明瞭さを整えることで、繊細なニュアンスがさらに活きやすくなります。"
    },
    wild: {
      title: "ワイルドボイス",
      examples: "長渕剛、Ado",
      description: "声帯の閉鎖感や息の圧が個性として出やすい歌声タイプです。エッジや迫力を活かしつつ、力みを抜くポイントを作ると説得力がさらに増しやすくなります。"
    },
    artistic: {
      title: "アーティスティックボイス",
      examples: "BUMP OF CHICKEN、aiko",
      description: "表現や響きの個性が出やすい歌声タイプです。フレーズごとの色づけや言葉の置き方を磨くことで、その人らしい印象がより強く残りやすくなります。"
    },
    charisma: {
      title: "カリスマボイス",
      examples: "宮本浩次、椎名林檎",
      description: "独特な世界観や空気感が魅力になりやすい歌声タイプです。技術的な安定に加えて、歌詞の解釈や間の作り方を磨くことで、聴き手を引き込む力が伸びやすくなります。"
    }
  }.freeze

  def singing_score_guide(score_key)
    SCORE_GUIDES.fetch(score_key)
  end

  def singing_score_comment(score)
    value = score.to_i

    if value >= 80
      "安定感が出ています。この良さを保ちながら、細かな表現を試していけそうです。"
    elsif value >= 60
      "土台は見えています。少しずつ整えることで、さらに伸ばしやすい状態です。"
    else
      "伸ばしどころがあります。まずは無理なく安定して声を出すところから整えていきましょう。"
    end
  end

  def singing_practice_menus(diagnosis)
    return singing_guitar_practice_menus(diagnosis) if diagnosis.performance_type_guitar?
    return singing_band_practice_menus(diagnosis) if diagnosis.performance_type_band?
    return singing_drums_practice_menus(diagnosis) if diagnosis.performance_type_drums?
    return singing_keyboard_practice_menus(diagnosis) if diagnosis.performance_type_keyboard?

    menus = []

    menus << pitch_practice_menu if diagnosis.pitch_score.to_i < 70
    menus << rhythm_practice_menu if diagnosis.rhythm_score.to_i < 70
    menus << expression_practice_menu if diagnosis.expression_score.to_i < 70

    if menus.empty?
      menus << strength_practice_menu
      menus << expression_practice_menu
    elsif diagnosis.overall_score.to_i >= 80 && menus.size < 3
      menus << strength_practice_menu
    end

    menus.first(3)
  end

  def singing_plan_feature_cards(customer)
    [
      {
        title: "履歴比較",
        plan_label: "Light以上",
        available: customer.has_feature?(:singing_diagnosis_comparison),
        description: "過去の診断と見比べて、練習前後の変化を追いやすくする機能を準備中です。"
      },
      {
        title: "詳細フィードバック",
        plan_label: "Core以上",
        available: customer.has_feature?(:singing_diagnosis_advanced_feedback),
        description: "音程・リズム・表現をもう一段深く振り返れる分析枠を準備中です。"
      },
      {
        title: "優先解析",
        plan_label: "Premium",
        available: customer.has_feature?(:singing_diagnosis_priority),
        description: "歌唱・演奏診断リクエストを優先解析対象として受け付けます。"
      }
    ]
  end

  def singing_practice_section_title(diagnosis)
    diagnosis.performance_type_band? ? "おすすめバンド練習メニュー" : "おすすめ練習メニュー"
  end

  def singing_practice_section_lead(diagnosis)
    if diagnosis.performance_type_band?
      "今回の診断をもとに、次回のスタジオやセッションでそのまま試しやすいバンド練習メニューを3つ前後に絞りました。"
    else
      "今回のスコアをもとに、次に試しやすい練習を2〜3個に絞りました。"
    end
  end

  def singing_score_comparison_rows(diagnosis)
    comparison = diagnosis.score_comparison
    return [] if comparison.blank?

    comparison.map do |attribute, values|
      delta = values[:delta]

      {
        label: SCORE_COMPARISON_LABELS.fetch(attribute),
        current: values[:current],
        previous: values[:previous],
        delta: delta,
        delta_label: singing_score_delta_label(delta),
        state: singing_score_delta_state(delta),
        message: singing_score_delta_message(delta)
      }
    end
  end

  def singing_history_growth_label(_diagnosis)
    "最近の伸び"
  end

  def singing_history_growth_hint(diagnosis, customer = nil)
    return "次回以降、成長傾向が表示されます" unless diagnosis.respond_to?(:completed?) && diagnosis.completed?

    premium_hint = singing_history_specific_growth_hint(diagnosis, customer)
    return premium_hint if premium_hint.present?

    singing_history_common_growth_hint(diagnosis)
  end

  def singing_history_common_growth_hint(diagnosis)
    comparison = diagnosis.respond_to?(:score_comparison) ? diagnosis.score_comparison : nil
    return "次回以降、成長傾向が表示されます" if comparison.blank?

    best_growth = comparison.each_with_object([]) do |(attribute, values), rows|
      delta = comparison_delta_value(values)
      next if delta.nil?

      rows << [attribute.to_sym, delta.to_i]
    end.max_by { |_attribute, delta| delta }

    return "前回との差が小さく、安定して積み上がっています" if best_growth.blank?

    attribute, delta = best_growth
    return "前回との差が小さく、安定して積み上がっています" unless delta.positive?

    case attribute
    when :overall_score
      "今回は総合スコアが上がっています"
    when :expression_score
      "表現が少しずつ安定してきています"
    else
      "前回より#{SCORE_COMPARISON_LABELS.fetch(attribute, 'スコア')}が伸びています"
    end
  end

  def singing_history_specific_growth_hint(diagnosis, customer = nil)
    return nil unless singing_history_premium_customer?(customer)

    comparison = diagnosis.respond_to?(:specific_score_comparison) ? diagnosis.specific_score_comparison : nil
    return nil if comparison.blank?

    best_growth = comparison.each_with_object([]) do |(key, values), rows|
      delta = comparison_delta_value(values)
      next if delta.nil?

      rows << [key.to_sym, delta.to_i]
    end.max_by { |_key, delta| delta }

    return nil if best_growth.blank?

    key, delta = best_growth
    return nil unless delta.positive?

    singing_history_specific_growth_message(diagnosis, key)
  end

  def singing_advanced_feedback_cards(diagnosis)
    configs = singing_advanced_feedback_targets(diagnosis)

    configs.map do |_key, config|
      score = singing_feedback_score(diagnosis, config[:score_key])
      band = singing_feedback_band(score)
      feedback = config[band]

      {
        label: config[:label],
        title: config[:title],
        score: score,
        band: band,
        summary: feedback[:summary],
        strength: feedback[:strength],
        next_step: feedback[:next_step]
      }
    end
  end

  def singing_advanced_feedback_available?(diagnosis)
    diagnosis.performance_type_vocal? ||
      diagnosis.performance_type_guitar? ||
      diagnosis.performance_type_bass? ||
      diagnosis.performance_type_drums? ||
      diagnosis.performance_type_keyboard? ||
      diagnosis.performance_type_band?
  end

  def singing_advanced_feedback_lead(diagnosis)
    return "スコアをもとに、音程・リズム・表現をもう一段細かく読み解きます。評価ではなく、次の練習を決めるためのヒントとしてご活用ください。" if diagnosis.performance_type_vocal?
    return "ギター詳細スコアをもとに、アタック・ミュート・安定感・全体のまとまりをもう一段細かく読み解きます。評価ではなく、次の練習を決めるためのヒントとしてご活用ください。" if diagnosis.performance_type_guitar?
    return "ベース詳細スコアをもとに、グルーヴ・音価・安定感・全体のまとまりをもう一段細かく読み解きます。評価ではなく、次の練習を決めるためのヒントとしてご活用ください。" if diagnosis.performance_type_bass?
    return "ドラム詳細スコアをもとに、テンポ安定・リズム精度・ダイナミクス・フィルコントロール・全体のまとまりをもう一段細かく読み解きます。評価ではなく、次の練習を決めるためのヒントとしてご活用ください。" if diagnosis.performance_type_drums?
    return "キーボード詳細スコアをもとに、和音の安定・音のつながり・タッチ・ハーモニー・全体のまとまりをもう一段細かく読み解きます。評価ではなく、次の練習を決めるためのヒントとしてご活用ください。" if diagnosis.performance_type_keyboard?
    return "バンド演奏の詳細スコアをもとに、アンサンブル力・役割理解・音量バランス・グルーヴ・ダイナミクス・全体のまとまりをもう一段細かく読み解きます。評価ではなく、次の練習を決めるためのヒントとしてご活用ください。" if diagnosis.performance_type_band?

    "#{diagnosis.performance_type_label}向けの詳細フィードバックは準備中です。現在は共通スコアと詳細スコアを中心に、演奏の振り返りへご活用ください。"
  end

  def singing_advanced_feedback_locked_lead(diagnosis)
    return "Core以上では、音程・リズム・表現をもう一段深く読み解く詳細フィードバックを確認できます。" if diagnosis.performance_type_vocal?
    return "Core以上では、グルーヴ・音価・安定感をもう一段深く読み解くベース向け詳細フィードバックを確認できます。" if diagnosis.performance_type_bass?
    return "Core以上では、テンポ安定・リズム精度・ダイナミクス・フィルコントロールをもう一段深く読み解くドラム向け詳細フィードバックを確認できます。" if diagnosis.performance_type_drums?
    return "Core以上では、和音の安定・音のつながり・タッチ・ハーモニーをもう一段深く読み解くキーボード向け詳細フィードバックを確認できます。" if diagnosis.performance_type_keyboard?
    return "Core以上では、アンサンブル力・役割理解・音量バランス・グルーヴ・ダイナミクスをもう一段深く読み解くバンド向け詳細フィードバックを確認できます。" if diagnosis.performance_type_band?

    "Core以上では、#{diagnosis.performance_type_label}向けの詳細フィードバックを今後確認できるよう準備しています。"
  end

  def singing_common_score_cards(diagnosis)
    configs = COMMON_SCORE_CARD_CONFIGS[diagnosis.performance_type.to_s] || COMMON_SCORE_CARD_CONFIGS["vocal"]

    configs.map do |config|
      score = diagnosis.public_send(config[:key]) if diagnosis.respond_to?(config[:key])

      {
        key: config[:key],
        label: config[:label],
        short_label: config[:short_label],
        score: score,
        comment: singing_score_comment(score)
      }
    end
  end

  def singing_specific_score_section_title(diagnosis)
    "#{diagnosis.performance_type_label}詳細スコア"
  end

  def singing_band_ensemble_section_title(_diagnosis)
    "アンサンブル診断"
  end

  def singing_band_ensemble_section_description(_diagnosis)
    "バンド全体の音量バランス、リズムの揃い、グルーヴ、役割理解、抑揚、一体感をもとに、演奏全体のまとまりを診断しています。"
  end

  def singing_performance_type_cards
    [
      {
        key: "vocal",
        label: "ボーカル診断",
        description: "音程・リズム・表現のバランスから、歌声の今を確認できます。"
      },
      {
        key: "guitar",
        label: "ギター診断",
        description: "アタックやミュート、安定感をもとに演奏の輪郭を振り返れます。"
      },
      {
        key: "bass",
        label: "ベース診断",
        description: "グルーヴ、音価、土台の安定感から低音の支え方を確認できます。"
      },
      {
        key: "drums",
        label: "ドラム診断",
        description: "テンポ安定、リズム精度、強弱からビートの芯を見直せます。"
      },
      {
        key: "keyboard",
        label: "キーボード診断",
        description: "和音の安定、音のつながり、タッチから伴奏のまとまりを見られます。"
      },
      {
        key: "band",
        label: "バンド演奏診断",
        description: "音量バランス・リズムの揃い・グルーヴ・一体感を診断",
        badges: ["NEW", "アンサンブル対応", "Premium相性◎"],
        featured: true
      }
    ]
  end

  def singing_band_promo_catch_copy
    "「うまいのにバンドだと微妙」を、アンサンブル力から見える化。"
  end

  def singing_band_promo_description
    "バンド演奏診断では、音量バランス、リズムの揃い、グルーヴ、役割理解、抑揚、一体感をもとに、バンド全体のまとまりを診断します。"
  end

  def singing_band_promo_recommended_for
    [
      "セッション音源を振り返りたい方",
      "バンド練習の改善点を見つけたい方",
      "個人練習だけでなく、全体のまとまりを高めたい方",
      "ライブ前にバンド全体の仕上がりを確認したい方"
    ]
  end

  def singing_band_promo_upload_note
    "30秒以上のバンド演奏音源がおすすめです。スマホ録音でもOKですが、極端に音が小さい・音割れしている音源は診断精度が下がる場合があります。"
  end

  def singing_band_premium_promo
    "Premiumでは、診断結果に応じて『今週のバンド練習テーマ』『スタジオでやること』『録音チェックポイント』まで確認できます。"
  end

  def singing_band_analysis_debug_visible?(diagnosis)
    return false unless Rails.env.development?
    return false unless diagnosis.respond_to?(:performance_type_band?) && diagnosis.performance_type_band?

    singing_band_analysis_debug_payload(diagnosis).present?
  end

  def singing_band_payload_check_visible?(diagnosis)
    return false unless Rails.env.development?
    return false unless diagnosis.respond_to?(:performance_type_band?) && diagnosis.performance_type_band?

    payload = diagnosis.respond_to?(:result_payload) ? diagnosis.result_payload : nil
    payload.respond_to?(:[])
  end

  def singing_band_payload_check_items(diagnosis)
    payload = diagnosis.respond_to?(:result_payload) ? diagnosis.result_payload : nil
    payload = {} unless payload.respond_to?(:[])

    [
      singing_band_payload_check_item(payload, "performance_type", label: "performance_type"),
      singing_band_payload_check_item(payload, "overall_score", label: "overall_score"),
      singing_band_payload_check_item(payload, "pitch_score", label: "pitch_score"),
      singing_band_payload_check_item(payload, "rhythm_score", label: "rhythm_score"),
      singing_band_payload_check_item(payload, "expression_score", label: "expression_score"),
      singing_band_payload_check_item(payload, %w[specific balance], label: "specific.balance"),
      singing_band_payload_check_item(payload, %w[specific tightness], label: "specific.tightness"),
      singing_band_payload_check_item(payload, %w[specific groove], label: "specific.groove"),
      singing_band_payload_check_item(payload, %w[specific role_clarity], label: "specific.role_clarity"),
      singing_band_payload_check_item(payload, %w[specific dynamics], label: "specific.dynamics"),
      singing_band_payload_check_item(payload, %w[specific cohesion], label: "specific.cohesion"),
      singing_band_payload_check_item(payload, %w[quality_flags too_short], label: "quality_flags.too_short"),
      singing_band_payload_check_item(payload, %w[quality_flags too_quiet], label: "quality_flags.too_quiet"),
      singing_band_payload_check_item(payload, %w[quality_flags too_loud], label: "quality_flags.too_loud"),
      singing_band_payload_check_item(payload, %w[quality_flags clipping_detected], label: "quality_flags.clipping_detected"),
      singing_band_payload_check_item(payload, %w[quality_flags mostly_silent], label: "quality_flags.mostly_silent"),
      singing_band_payload_check_item(payload, %w[quality_flags low_confidence], label: "quality_flags.low_confidence"),
      singing_band_payload_check_item(payload, "quality_message", label: "quality_message"),
      singing_band_payload_check_item(payload, "analysis_debug", label: "analysis_debug"),
      singing_band_payload_check_item(payload, %w[analysis_debug rms_mean], label: "analysis_debug.rms_mean")
    ]
  end

  def singing_band_analysis_debug_sections(diagnosis)
    debug = singing_band_analysis_debug_payload(diagnosis)
    return [] unless debug.present?

    spectral_balance = singing_band_analysis_debug_hash(debug[:spectral_balance] || debug["spectral_balance"])
    cohesion_inputs = singing_band_analysis_debug_hash(debug[:cohesion_inputs] || debug["cohesion_inputs"])

    [
      {
        title: "基本指標",
        items: [
          { label: "RMS平均", value: singing_band_analysis_debug_metric(debug, :rms_mean) },
          { label: "RMSばらつき", value: singing_band_analysis_debug_metric(debug, :rms_std) },
          { label: "peak値", value: singing_band_analysis_debug_metric(debug, :peak) },
          { label: "無音率", value: singing_band_analysis_debug_metric(debug, :silence_ratio) },
          { label: "onset候補数", value: singing_band_analysis_debug_integer_metric(debug, :onset_count) },
          { label: "onset間隔のばらつき", value: singing_band_analysis_debug_metric(debug, :onset_interval_std) },
          { label: "dynamics range", value: singing_band_analysis_debug_metric(debug, :dynamics_range) }
        ]
      },
      {
        title: "帯域バランス",
        items: [
          { label: "low", value: singing_band_analysis_debug_metric(spectral_balance, :low) },
          { label: "mid", value: singing_band_analysis_debug_metric(spectral_balance, :mid) },
          { label: "high", value: singing_band_analysis_debug_metric(spectral_balance, :high) }
        ]
      },
      {
        title: "cohesion計算入力",
        items: [
          { label: "音量バランス", value: singing_band_analysis_debug_integer_metric(cohesion_inputs, :balance) },
          { label: "リズムの揃い", value: singing_band_analysis_debug_integer_metric(cohesion_inputs, :tightness) },
          { label: "グルーヴ", value: singing_band_analysis_debug_integer_metric(cohesion_inputs, :groove) },
          { label: "役割理解", value: singing_band_analysis_debug_integer_metric(cohesion_inputs, :role_clarity) },
          { label: "ダイナミクス", value: singing_band_analysis_debug_integer_metric(cohesion_inputs, :dynamics) }
        ]
      }
    ]
  end

  def singing_band_quality_notice_visible?(diagnosis)
    return false unless diagnosis.respond_to?(:performance_type_band?) && diagnosis.performance_type_band?

    singing_band_quality_message(diagnosis).present?
  end

  def singing_band_quality_message(diagnosis)
    payload = diagnosis.respond_to?(:result_payload) ? diagnosis.result_payload : nil
    return nil unless payload.respond_to?(:[])

    quality_message = payload[:quality_message] || payload["quality_message"]
    quality_message = quality_message.to_s.strip
    return quality_message if quality_message.present?

    flags = singing_band_quality_flags(diagnosis)
    return nil unless ActiveModel::Type::Boolean.new.cast(flags[:low_confidence] || flags["low_confidence"])

    reasons = []
    reasons << "音源が少し短め" if ActiveModel::Type::Boolean.new.cast(flags[:too_short] || flags["too_short"])
    reasons << "無音区間がやや多め" if ActiveModel::Type::Boolean.new.cast(flags[:mostly_silent] || flags["mostly_silent"])
    reasons << "音量がやや小さめ" if ActiveModel::Type::Boolean.new.cast(flags[:too_quiet] || flags["too_quiet"])
    if ActiveModel::Type::Boolean.new.cast(flags[:clipping_detected] || flags["clipping_detected"]) ||
       ActiveModel::Type::Boolean.new.cast(flags[:too_loud] || flags["too_loud"])
      reasons << "音量が大きく音割れの影響を受けた可能性"
    end

    lead = reasons.first(2).join("、")
    lead = "録音条件の影響" if lead.blank?
    "今回の音源は#{lead}ため、診断結果は参考値としてご覧ください。次回は30秒以上の演奏を録音すると、より安定した診断につながります。"
  end

  def singing_band_quality_flags(diagnosis)
    payload = diagnosis.respond_to?(:result_payload) ? diagnosis.result_payload : nil
    return {} unless payload.respond_to?(:[])

    singing_band_analysis_debug_hash(payload[:quality_flags] || payload["quality_flags"])
  end

  def singing_specific_score_section_description(diagnosis)
    SPECIFIC_SCORE_SECTION_DESCRIPTIONS[diagnosis.performance_type.to_s] ||
      "診断対象に合わせた補足スコアです。共通スコアとあわせて、次に意識するポイントの目安としてご確認ください。"
  end

  def singing_specific_score_comparison_section_title(diagnosis)
    "#{diagnosis.performance_type_label}詳細スコアの前回比"
  end

  def singing_specific_score_cards(diagnosis)
    return singing_band_specific_score_cards(diagnosis) if diagnosis.performance_type_band?

    specific_scores = singing_specific_scores(diagnosis)
    return [] if specific_scores.blank?

    specific_scores.each_with_object([]) do |(key, score), cards|
      next if score.blank?

      cards << {
        key: key.to_sym,
        label: singing_specific_score_label(key, diagnosis.performance_type),
        score: score.to_i,
        comment: singing_specific_score_comment(score)
      }
    end
  end

  def singing_specific_scores(diagnosis)
    payload = diagnosis.respond_to?(:result_payload) ? diagnosis.result_payload : nil
    return {} unless payload.respond_to?(:[])

    specific = payload[:specific] || payload["specific"]
    return {} unless specific.respond_to?(:each_with_object)

    specific.each_with_object({}) do |(key, value), scores|
      normalized_value = singing_normalize_score(value)
      scores[key.to_sym] = normalized_value unless normalized_value.nil?
    end
  end

  def singing_band_specific_score_cards(diagnosis)
    BAND_ENSEMBLE_SCORE_CONFIGS.map do |config|
      score = singing_band_specific_score_value(diagnosis, config[:source_keys])

      {
        key: config[:key],
        label: config[:label],
        score: score,
        description: config[:description],
        rating: singing_band_specific_rating(score),
        comment: singing_band_specific_score_comment(config[:key], score)
      }
    end
  end

  def singing_band_specific_score_value(diagnosis, source_keys)
    source_keys.each do |key|
      score = singing_feedback_score(diagnosis, key)
      return score unless score.nil?
    end

    nil
  end

  def singing_band_specific_rating(score)
    value = singing_normalize_score(score)
    return "データ不足" if value.nil?
    return "とても良い" if value >= 85
    return "良い" if value >= 70
    return "改善余地あり" if value >= 50

    "重点改善"
  end

  def singing_band_specific_score_comment(key, score)
    value = singing_normalize_score(score)
    return "今回は十分なデータがそろわなかったため、次回は同じ編成と音量感で録音すると比較しやすくなります。" if value.nil?

    case key.to_sym
    when :balance
      return "とても良い状態です。主旋律やボーカルが自然に前へ出ながら、伴奏も埋もれず支えられています。" if value >= 85
      return "良い状態です。さらにボーカルや主旋律を中心に整理できると、聴きやすさが増します。" if value >= 70
      return "改善余地があります。出過ぎるパートを少し引き算すると、全体の見通しがよくなりやすいです。" if value >= 50
      "重点改善ポイントです。まずは全体音量を一段下げ、主旋律が自然に聴こえる位置から組み直しましょう。"
    when :tightness
      return "とても良い状態です。リズム隊と伴奏、歌の入りがそろっていて、バンド全体に安心感があります。" if value >= 85
      return "良い状態です。入りと戻りをもう少しそろえると、まとまりがさらに強くなります。" if value >= 70
      return "改善余地があります。短い区間で拍の頭をそろえるだけでも、印象がかなり変わりやすいです。" if value >= 50
      "重点改善ポイントです。ドラムとベースを基準にして、全員の入りを短い区間から合わせ直しましょう。"
    when :groove
      return "とても良い状態です。演奏全体に自然なノリと推進力があり、曲が前へ進んで聴こえます。" if value >= 85
      return "良い状態です。前ノリ・後ノリの感覚をそろえると、さらに気持ちよい流れになります。" if value >= 70
      return "改善余地があります。リズム隊の重心にほかのパートがどう乗るかを確認すると整いやすいです。" if value >= 50
      "重点改善ポイントです。まずはベースとドラムだけで1コーラス合わせ、ノリの軸を共有しましょう。"
    when :role_clarity
      return "とても良い状態です。各パートの役割が明確で、出る場面と支える場面が整理されています。" if value >= 85
      return "良い状態です。場面ごとの主役をさらに明確にすると、アンサンブルの説得力が増します。" if value >= 70
      return "改善余地があります。同時に前へ出る音を減らすだけでも、見通しが良くなりやすいです。" if value >= 50
      "重点改善ポイントです。Aメロ・サビごとに、誰が前に出るかを決めてから合わせ直してみましょう。"
    when :dynamics
      return "とても良い状態です。曲の展開に合わせた抑揚があり、演奏に立体感があります。" if value >= 85
      return "良い状態です。Aメロとサビの差をもう少し意識すると、展開がさらに伝わりやすくなります。" if value >= 70
      return "改善余地があります。どこで抑えてどこで広げるかを共有すると、まとまりが出やすいです。" if value >= 50
      "重点改善ポイントです。Aメロ・Bメロ・サビの音量差を先に決めて、短く反復してみましょう。"
    else
      return "とても良い状態です。バンド全体がひとつの演奏として自然にまとまって聴こえます。" if value >= 85
      return "良い状態です。細かな音量差や入り方をそろえると、一体感がさらに強まります。" if value >= 70
      return "改善余地があります。噛み合い、音量差、ノリを順番に見ると改善しやすいです。" if value >= 50
      "重点改善ポイントです。8小節ほどに絞って録音し、全員で一体感が崩れる原因を確認してみましょう。"
    end
  end

  def singing_specific_score_label(key, performance_type)
    labels = SPECIFIC_SCORE_LABELS[performance_type.to_s] || {}
    labels[key.to_sym] || key.to_s.sub(/_score\z/, "").humanize
  end

  def singing_specific_score_comparison_rows(diagnosis)
    comparison = diagnosis.specific_score_comparison
    return [] if comparison.blank?

    comparison.map do |key, values|
      delta = values[:delta]

      {
        key: key,
        label: singing_specific_score_label(key, diagnosis.performance_type),
        current: values[:current],
        previous: values[:previous],
        delta: delta,
        delta_label: singing_score_delta_label(delta),
        state: singing_score_delta_state(delta),
        message: singing_specific_score_delta_message(delta)
      }
    end
  end

  def singing_radar_chart_enabled?(diagnosis)
    singing_radar_chart_data(diagnosis).size >= 3
  end

  def singing_growth_chart_title(_diagnosis)
    "成長推移"
  end

  def singing_growth_chart_lead(diagnosis, diagnoses)
    count = Array(diagnoses).size
    return "次回以降、#{diagnosis.performance_type_label}のスコア推移が見えるようになります。" if count <= 1

    "同じ#{diagnosis.performance_type_label}の完了済み診断だけを並べて、これまでのスコア変化を表示しています。"
  end

  def singing_growth_chart_enabled?(diagnoses)
    Array(diagnoses).size >= 2
  end

  def singing_growth_chart_data(diagnoses)
    entries = Array(diagnoses).select { |diagnosis| diagnosis.respond_to?(:completed?) ? diagnosis.completed? : true }
    return [] if entries.blank?

    entries.map do |diagnosis|
      {
        label: growth_chart_label(diagnosis),
        overall_score: diagnosis.overall_score.to_i,
        pitch_score: diagnosis.pitch_score.to_i,
        rhythm_score: diagnosis.rhythm_score.to_i,
        expression_score: diagnosis.expression_score.to_i
      }
    end
  end

  def singing_growth_chart_series(_diagnosis)
    [
      { key: :overall_score, label: "総合", color: "#059669" },
      { key: :pitch_score, label: "音程", color: "#2563eb" },
      { key: :rhythm_score, label: "リズム", color: "#f97316" },
      { key: :expression_score, label: "表現", color: "#7c3aed" }
    ]
  end

  def singing_specific_growth_chart_title(_diagnosis)
    "Premium限定：パート別成長推移"
  end

  def singing_specific_growth_chart_lead(diagnosis, diagnoses)
    count = Array(diagnoses).size
    return "次回以降、#{diagnosis.performance_type_label}の細かな伸びが見えるようになります。" if count <= 1

    "#{diagnosis.performance_type_label}の補足スコアだけを並べて、細かな伸び方を見える化しています。"
  end

  def singing_specific_growth_chart_locked_lead(diagnosis)
    case diagnosis.performance_type.to_s
    when "guitar"
      "Premiumでは、アタック・ミュート・安定感など、ギター演奏の細かな成長推移を確認できます。"
    when "bass"
      "Premiumでは、グルーヴ・音価・安定感など、ベース演奏の細かな成長推移を確認できます。"
    when "drums"
      "Premiumでは、テンポ安定・リズム精度・ダイナミクス・フィルなど、ドラム演奏の細かな成長推移を確認できます。"
    when "keyboard"
      "Premiumでは、コード安定・音のつながり・タッチ・ハーモニーなど、キーボード演奏の細かな成長推移を確認できます。"
    when "band"
      "Premiumでは、アンサンブル力・役割理解・音量バランス・グルーヴ・ダイナミクスなど、バンド演奏の細かな成長推移を確認できます。"
    else
      "Premiumでは、声量・発音・リラックス・ミックスボイスなど、ボーカルの細かな成長推移を確認できます。"
    end
  end

  def singing_specific_growth_chart_enabled?(diagnoses, diagnosis)
    Array(diagnoses).size >= 2 && singing_specific_growth_chart_series(diagnosis, diagnoses).any?
  end

  def singing_specific_growth_chart_series(diagnosis, diagnoses)
    keys = SPECIFIC_SCORE_LABELS.fetch(diagnosis.performance_type.to_s, {}).keys
    entries = Array(diagnoses)

    keys.filter_map do |key|
      next unless entries.any? { |entry| singing_specific_scores(entry)[key].present? }

      {
        key: key,
        label: singing_specific_score_label(key, diagnosis.performance_type),
        color: specific_growth_chart_color(key, diagnosis.performance_type)
      }
    end
  end

  def singing_specific_growth_chart_data(diagnosis, diagnoses)
    series_keys = singing_specific_growth_chart_series(diagnosis, diagnoses).map { |series| series[:key] }
    return [] if series_keys.blank?

    Array(diagnoses).select { |entry| entry.respond_to?(:completed?) ? entry.completed? : true }.map do |entry|
      item = { label: growth_chart_label(entry) }

      series_keys.each do |key|
        score = singing_specific_scores(entry)[key]
        item[key] = score.present? ? score.to_i : nil
      end

      item
    end
  end

  def singing_specific_growth_summary_lead(diagnosis, diagnoses)
    return "次回以降、細かな成長傾向が見えるようになります。" if Array(diagnoses).size < 2

    "#{diagnosis.performance_type_label}の最近の変化を短くまとめています。"
  end

  def singing_specific_growth_summary_cards(diagnosis, diagnoses)
    return [] unless Array(diagnoses).size >= 2

    entries = Array(diagnoses).select { |entry| entry.respond_to?(:completed?) ? entry.completed? : true }
    return [] if entries.size < 2

    current = entries.last
    previous = entries[-2]
    current_scores = singing_specific_scores(current)
    previous_scores = singing_specific_scores(previous)
    return [] if current_scores.blank?

    deltas = current_scores.each_with_object({}) do |(key, value), memo|
      previous_value = previous_scores[key]
      next if previous_value.blank?

      memo[key] = value.to_i - previous_value.to_i
    end

    best_key = current_scores.max_by { |_key, value| value.to_i }&.first
    lowest_key = current_scores.min_by { |_key, value| value.to_i }&.first
    growth_key = deltas.max_by { |_key, value| value.to_i }&.first
    growth_delta = growth_key.present? ? deltas[growth_key].to_i : nil

    cards = []

    if growth_key.present? && growth_delta.positive?
      cards << {
        label: "最近伸びている項目",
        title: singing_specific_score_label(growth_key, diagnosis.performance_type),
        body: singing_specific_growth_summary_message(diagnosis, growth_key, :growth)
      }
    end

    if best_key.present?
      cards << {
        label: "今の強み",
        title: singing_specific_score_label(best_key, diagnosis.performance_type),
        body: singing_specific_growth_summary_message(diagnosis, best_key, :strength)
      }
    end

    if lowest_key.present?
      cards << {
        label: "次の改善ポイント",
        title: singing_specific_score_label(lowest_key, diagnosis.performance_type),
        body: singing_specific_growth_summary_message(diagnosis, lowest_key, :focus)
      }
    end

    cards
  end

  def singing_specific_growth_chart_note(diagnosis, diagnoses)
    return nil unless singing_specific_growth_chart_missing_data?(diagnosis, diagnoses)

    "#{diagnosis.performance_type_label}の過去データに一部項目がない場合、該当する線が途中で途切れることがあります。"
  end

  def singing_specific_growth_chart_missing_data?(diagnosis, diagnoses)
    series_keys = singing_specific_growth_chart_series(diagnosis, diagnoses).map { |series| series[:key] }
    return false if series_keys.blank?

    Array(diagnoses).any? do |entry|
      scores = singing_specific_scores(entry)
      series_keys.any? { |key| scores[key].blank? }
    end
  end

  def singing_radar_chart_title(diagnosis)
    return "ギター演奏の特徴バランス" if diagnosis.performance_type_guitar?
    return "ベース演奏の特徴バランス" if diagnosis.performance_type_bass?
    return "キーボード演奏の特徴バランス" if diagnosis.performance_type_keyboard?
    return "バンド演奏の特徴バランス" if diagnosis.performance_type_band?

    "3項目のバランス"
  end

  def singing_radar_chart_description(diagnosis)
    return "リズム・表現・アタック・ミュート・安定感のバランスを補助的に表示しています。ギター詳細スコアとあわせてご確認ください。" if diagnosis.performance_type_guitar?
    return "リズム・表現・グルーヴ・音価・安定感のバランスを補助的に表示しています。ベース詳細スコアとあわせてご確認ください。" if diagnosis.performance_type_bass?
    return "音程・リズム・表現・コード安定・音のつながり・タッチ・ハーモニーのバランスを補助的に表示しています。キーボード詳細スコアとあわせてご確認ください。" if diagnosis.performance_type_keyboard?
    return "調和・リズムの揃い・ダイナミクス・役割理解・音量バランス・グルーヴ・全体のまとまりのバランスを補助的に表示しています。バンド演奏詳細スコアとあわせてご確認ください。" if diagnosis.performance_type_band?

    "音程・リズム・表現のバランスを補助的に表示しています。詳しい見方は下のスコア説明をご確認ください。"
  end

  def singing_radar_chart_data(diagnosis)
    configs = singing_radar_chart_configs(diagnosis)
    return [] if configs.blank?

    configs.each_with_object([]) do |config, data|
      score = singing_radar_score(diagnosis, config[:key])
      next if score.blank?

      data << {
        key: config[:key],
        label: config[:label],
        score: score.to_i
      }
    end
  end

  def singing_premium_voice_check_items(diagnosis)
    [
      premium_check_item("音程", "メロディの正確性、フラットしやすさの目安です。", diagnosis.pitch_score),
      premium_check_item("声量", "声の太さ、響き、前に出る力の目安です。", premium_average_score(diagnosis.overall_score, diagnosis.expression_score)),
      premium_check_item("表現力", "ビブラート、抑揚、語尾のニュアンスなどの目安です。", diagnosis.expression_score),
      premium_check_item("リラックス", "力み具合、喉の締め付けにくさの目安です。", premium_average_score(diagnosis.pitch_score, diagnosis.rhythm_score)),
      premium_check_item("発音", "歌詞の明瞭性、言葉の届きやすさの目安です。", premium_average_score(diagnosis.pitch_score, diagnosis.rhythm_score, diagnosis.expression_score)),
      premium_check_item("リズム感", "歌のリズム、ノリ、フレーズの入り方の目安です。", diagnosis.rhythm_score)
    ]
  end

  def singing_premium_mix_voice_check_items(diagnosis)
    [
      premium_check_item("声帯の閉鎖", "エッジボイスで体感しやすい、声の芯や密度の目安です。", premium_average_score(diagnosis.overall_score, diagnosis.expression_score)),
      premium_check_item("声帯のテンション", "裏声や高音で体感しやすい、音の張りと伸びの目安です。", premium_average_score(diagnosis.pitch_score, diagnosis.overall_score)),
      premium_check_item("喉の開放", "あくびの感覚で体感しやすい、喉まわりの余裕の目安です。", premium_average_score(diagnosis.pitch_score, diagnosis.rhythm_score))
    ]
  end

  def singing_premium_voice_type(diagnosis)
    scores = singing_premium_voice_type_scores(diagnosis)
    key = scores.max_by { |_type, score| score }&.first || :artistic
    PREMIUM_VOICE_TYPE_PROFILES.fetch(key).merge(key: key, score: scores[key])
  end

  def singing_premium_voice_type_map(diagnosis)
    selected_type = singing_premium_voice_type(diagnosis)

    PREMIUM_VOICE_TYPE_PROFILES.map do |key, profile|
      profile.merge(
        key: key,
        selected: key == selected_type[:key],
        short_description: singing_premium_voice_type_short_description(key)
      )
    end
  end

  def singing_premium_type_diagnosis_accent_key(diagnosis)
    diagnosis.performance_type.to_s.presence_in(%w[vocal guitar bass drums keyboard band]) || "vocal"
  end

  def singing_premium_type_diagnosis_icon(diagnosis)
    case singing_premium_type_diagnosis_accent_key(diagnosis)
    when "guitar"
      "🎸"
    when "bass"
      "🎵"
    when "drums"
      "🥁"
    when "keyboard"
      "🎹"
    when "band"
      "🎼"
    else
      "🎤"
    end
  end

  def singing_premium_type_diagnosis_title(diagnosis)
    case diagnosis.performance_type.to_s
    when "guitar"
      "ギター演奏の深掘り診断"
    when "bass"
      "ベース演奏の土台診断"
    when "drums"
      "ドラム演奏のリズム診断"
    when "keyboard"
      "キーボード演奏の響き診断"
    when "band"
      "バンド演奏のアンサンブル診断"
    else
      "歌唱の深掘り診断"
    end
  end

  def singing_premium_type_diagnosis_lead(diagnosis)
    case diagnosis.performance_type.to_s
    when "guitar"
      "発音の輪郭、余韻の整理、演奏の芯を読み解き、ギター演奏としての映え方を整理します。"
    when "bass"
      "グルーヴ、音価、低音の土台感から、曲全体を支える演奏傾向を読み解きます。"
    when "drums"
      "テンポの支え方、リズムの芯、強弱とフィルのまとまりから、ビートの説得力を読み解きます。"
    when "keyboard"
      "和音の安定、音のつながり、タッチ、ハーモニーから、伴奏としてのまとまりを読み解きます。"
    when "band"
      "アンサンブル、役割理解、音量バランス、グルーヴ、ダイナミクスから、バンド全体のまとまりを読み解きます。"
    else
      "今回の診断結果から、演奏の傾向を少し深く読み解きます。"
    end
  end

  def singing_premium_type_diagnosis_locked_lead(diagnosis)
    case diagnosis.performance_type.to_s
    when "guitar"
      "Premiumでは、発音・ミュート・安定感まで含めて、ギター演奏の傾向を深く読み解けます。"
    when "bass"
      "Premiumでは、グルーヴ・音価・土台感まで含めて、ベースとしての支え方を深く読み解けます。"
    when "drums"
      "Premiumでは、テンポ・リズム・フィルの流れまで含めて、ドラムの説得力を深く読み解けます。"
    when "keyboard"
      "Premiumでは、和音・タッチ・響きまで含めて、伴奏としてのまとまりを深く読み解けます。"
    when "band"
      "Premiumでは、アンサンブル・役割理解・音量バランス・グルーヴまで含めて、バンド全体のまとまりを深く読み解けます。"
    else
      "Premiumでは、診断結果をもとに演奏傾向をより深く読み解けます。"
    end
  end

  def singing_premium_type_diagnosis_cards(diagnosis)
    configs = singing_premium_type_diagnosis_configs(diagnosis)
    return [] if configs.blank?

    configs.map do |config|
      score = singing_feedback_score(diagnosis, config[:score_key]) || diagnosis.overall_score
      band = singing_feedback_band(score)
      band_text = config.fetch(band)

      {
        label: config[:label],
        title: config[:title],
        score: score.to_i,
        band: band,
        insight: band_text[:insight],
        strength: band_text[:strength],
        risk: band_text[:risk],
        next_theme: band_text[:next_theme],
        comparison_note: singing_premium_type_comparison_note(diagnosis, config[:score_key])
      }
    end
  end

  def singing_weekly_coach_title(_diagnosis)
    "Premium限定：今週の練習テーマ"
  end

  def singing_weekly_coach_available?(customer)
    customer.present? && customer.respond_to?(:has_feature?) && customer.has_feature?(:singing_diagnosis_priority)
  end

  def singing_weekly_coach_lead(diagnosis)
    "#{diagnosis.performance_type_label}の診断結果と直近の変化から、今週意識すると良い練習テーマを1つに絞って提案します。"
  end

  def singing_weekly_coach_locked_lead(diagnosis)
    "Premiumでは、#{diagnosis.performance_type_label}の診断履歴から今週の練習テーマを自動で提案します。"
  end

  def singing_weekly_coach_card(diagnosis)
    target = singing_weekly_coach_target(diagnosis)
    practice_menu = singing_weekly_coach_practice_menu(diagnosis, target[:key])
    coach = {
      theme: target[:theme],
      focus: target[:focus],
      practice_title: practice_menu[:title],
      practice_description: practice_menu[:description],
      encouragement: target[:encouragement],
      reference_note: singing_weekly_coach_reference_note(diagnosis)
    }

    if diagnosis.respond_to?(:performance_type_band?) && diagnosis.performance_type_band?
      coach[:quality_note] = singing_band_weekly_coach_quality_note(diagnosis)
      coach[:goal] = target[:goal]
      coach[:studio_steps] = Array(target[:studio_steps]).presence || [practice_menu[:description]].compact
      coach[:recording_points] = Array(target[:recording_points])
      coach[:homework] = target[:homework]
    end

    coach
  end

  def singing_reference_match_badge_label(level)
    case level.to_s
    when "exact"
      "かなり近い"
    when "close"
      "近い"
    when "near"
      "やや差あり"
    when "moderate"
      "差あり"
    when "far"
      "離れ気味"
    when "unknown"
      "参考程度"
    else
      level.presence || "判定なし"
    end
  end

  def singing_reference_match_badge_class(level)
    suffix = case level.to_s
             when "exact", "close"
               "good"
             when "near", "moderate"
               "caution"
             when "far"
               "warn"
             else
               "muted"
             end

    "singing-diagnosis__reference-badge singing-diagnosis__reference-badge--#{suffix}"
  end

  private

  def comparison_delta_value(values)
    return nil unless values.respond_to?(:[])

    values[:delta] || values["delta"]
  end

  def singing_history_premium_customer?(customer)
    customer.present? && customer.respond_to?(:has_feature?) && customer.has_feature?(:singing_diagnosis_priority)
  end

  def singing_history_specific_growth_message(diagnosis, key)
    label = singing_specific_score_label(key, diagnosis.performance_type)

    case diagnosis.performance_type.to_s
    when "guitar"
      return "#{label}が安定してきています" if key.to_sym == :stability_score
      "前回より#{label}が伸びています"
    when "bass"
      return "グルーヴが安定してきています" if key.to_sym == :groove_score
      "前回より#{label}が伸びています"
    when "drums"
      return "テンポ安定が伸びています" if key.to_sym == :tempo_stability_score
      "前回より#{label}が伸びています"
    when "keyboard"
      return "タッチが整ってきています" if key.to_sym == :touch_score
      "前回より#{label}が伸びています"
    when "band"
      return "アンサンブル力が整ってきています" if key.to_sym == :ensemble_score
      return "音量バランスが整ってきています" if %i[volume_balance_score balance].include?(key.to_sym)
      return "リズムの揃いが安定してきています" if %i[rhythm_unity_score tightness].include?(key.to_sym)
      "前回より#{label}が伸びています"
    when "vocal"
      return "発音が安定してきています" if key.to_sym == :pronunciation_score
      "前回より#{label}が伸びています"
    else
      "前回より#{label}が伸びています"
    end
  end

  def singing_weekly_coach_target(diagnosis)
    specific_scores = singing_specific_scores(diagnosis)
    specific_comparison = diagnosis.specific_score_comparison if diagnosis.respond_to?(:specific_score_comparison)

    if specific_comparison.present?
      stalled_target = specific_comparison.each_with_object([]) do |(key, values), rows|
        delta = comparison_delta_value(values)
        next if delta.nil?

        rows << [key.to_sym, delta.to_i]
      end.min_by { |_key, delta| delta }

      if stalled_target.present? && stalled_target.last.negative?
        return singing_weekly_coach_copy(diagnosis, stalled_target.first, :recovery)
      end
    end

    if (tempo_bias_key = singing_weekly_coach_tempo_bias_key(diagnosis)).present?
      return singing_weekly_coach_copy(diagnosis, tempo_bias_key, :tempo_bias)
    end

    if specific_scores.present?
      focus_key = specific_scores.min_by { |_key, value| value.to_i }&.first
      return singing_weekly_coach_copy(diagnosis, focus_key, :focus) if focus_key.present?
    end

    common_focus_key = [
      :overall_score,
      :pitch_score,
      :rhythm_score,
      :expression_score
    ].min_by do |key|
      value = diagnosis.respond_to?(key) ? diagnosis.public_send(key) : nil
      value.present? ? value.to_i : 10_000
    end

    singing_weekly_coach_copy(diagnosis, common_focus_key, :foundation)
  end

  def singing_weekly_coach_copy(diagnosis, key, mode)
    type = diagnosis.performance_type.to_s

    case type
    when "guitar"
      singing_weekly_guitar_coach_copy(key, mode)
    when "bass"
      singing_weekly_bass_coach_copy(key, mode)
    when "drums"
      singing_weekly_drums_coach_copy(key, mode)
    when "keyboard"
      singing_weekly_keyboard_coach_copy(key, mode)
    when "band"
      singing_weekly_band_coach_copy(key, mode)
    else
      singing_weekly_vocal_coach_copy(key, mode)
    end
  end

  def singing_weekly_coach_practice_menu(diagnosis, key)
    case diagnosis.performance_type.to_s
    when "guitar"
      case key.to_sym
      when :attack_score then guitar_attack_practice_menu
      when :muting_score then guitar_muting_practice_menu
      when :stability_score then guitar_stability_practice_menu
      when :rhythm_score then guitar_rhythm_practice_menu
      else singing_practice_menus(diagnosis).first || strength_practice_menu
      end
    when "bass"
      case key.to_sym
      when :groove_score, :rhythm_score then bass_groove_practice_menu
      when :note_length_score then bass_note_length_practice_menu
      when :stability_score, :overall_score then bass_stability_practice_menu
      else singing_practice_menus(diagnosis).first || bass_groove_practice_menu
      end
    when "drums"
      case key.to_sym
      when :tempo_stability_score then drums_tempo_practice_menu
      when :rhythm_precision_score, :rhythm_score then drums_precision_practice_menu
      when :dynamics_score, :expression_score then drums_dynamics_practice_menu
      when :fill_control_score then drums_fill_practice_menu
      else singing_practice_menus(diagnosis).first || drums_precision_practice_menu
      end
    when "keyboard"
      case key.to_sym
      when :chord_stability_score then keyboard_chord_practice_menu
      when :note_connection_score then keyboard_connection_practice_menu
      when :touch_score then keyboard_touch_practice_menu
      when :harmony_score then keyboard_harmony_practice_menu
      when :rhythm_score then keyboard_rhythm_practice_menu
      when :expression_score then keyboard_expression_practice_menu
      when :pitch_score then keyboard_pitch_practice_menu
      when :overall_score then keyboard_foundation_practice_menu
      else singing_practice_menus(diagnosis).first || keyboard_foundation_practice_menu
      end
    when "band"
      case key.to_sym
      when :ensemble_score then band_ensemble_practice_menu
      when :role_understanding_score, :role_clarity then band_role_practice_menu
      when :volume_balance_score, :balance then band_balance_practice_menu
      when :groove_score, :groove then band_groove_practice_menu
      when :dynamics_score, :dynamics, :expression_score then band_dynamics_practice_menu
      when :rhythm_unity_score, :tightness, :rhythm_score then band_rhythm_practice_menu
      when :cohesion_score, :cohesion, :overall_score then band_cohesion_practice_menu
      else singing_practice_menus(diagnosis).first || band_cohesion_practice_menu
      end
    else
      case key.to_sym
      when :volume_score then vocal_volume_practice_menu
      when :pronunciation_score then vocal_pronunciation_practice_menu
      when :relax_score then vocal_relax_practice_menu
      when :mix_voice_score then vocal_mix_voice_practice_menu
      when :rhythm_score then rhythm_practice_menu
      when :expression_score then expression_practice_menu
      when :pitch_score then pitch_practice_menu
      else singing_practice_menus(diagnosis).first || strength_practice_menu
      end
    end
  end

  def singing_weekly_coach_reference_note(diagnosis)
    reference = diagnosis.reference_comparison if diagnosis.respond_to?(:reference_comparison)
    return nil if reference.blank?

    tempo_note = singing_weekly_coach_tempo_reference_note(diagnosis, reference)
    key_note = singing_weekly_coach_key_reference_note(diagnosis, reference)

    [tempo_note, key_note].compact.first
  end

  def singing_weekly_coach_tempo_bias_key(diagnosis)
    reference = diagnosis.reference_comparison if diagnosis.respond_to?(:reference_comparison)
    return nil if reference.blank?

    tempo_level = reference[:tempo_match_level] || reference["tempo_match_level"]
    return nil unless tempo_level.to_s == "far"

    case diagnosis.performance_type.to_s
    when "bass"
      :groove_score
    when "drums"
      :tempo_stability_score
    when "band"
      :tightness
    else
      :rhythm_score
    end
  end

  def singing_weekly_vocal_coach_copy(key, mode)
    case key.to_sym
    when :pronunciation_score
      {
        key: key,
        theme: mode == :recovery ? "発音を立て直す週" : "発音を整える週",
        focus: "言葉の頭と語尾を少し丁寧に置いて、歌詞が自然に届く流れを意識しましょう。",
        encouragement: "発音が整うと、同じフレーズでも伝わり方がぐっと安定してきます。"
      }
    when :relax_score
      {
        key: key,
        theme: mode == :recovery ? "力みをほどく週" : "リラックスを育てる週",
        focus: "喉まわりの力を抜き、出しやすい高さで無理のない息の流れを作ることを優先しましょう。",
        encouragement: "余計な力が抜けるだけで、音程も表現もかなり伸ばしやすくなります。"
      }
    when :mix_voice_score
      {
        key: key,
        theme: mode == :recovery ? "高音のつながりを戻す週" : "ミックスボイスを整える週",
        focus: "地声と裏声の切り替わりが急になりすぎないよう、つながりをゆっくり確認しましょう。",
        encouragement: "高音のつながりは、少しずつ整えるほど歌全体の安心感につながります。"
      }
    when :pitch_score
      {
        key: key,
        theme: "音程の芯を整える週",
        focus: "狙った音に無理なく乗る感覚を作るため、出だしと語尾を丁寧にそろえましょう。",
        encouragement: "音程が整うと、今ある良さももっとまっすぐ届きやすくなります。"
      }
    when :rhythm_score
      {
        key: key,
        theme: mode == :tempo_bias ? "テンポ感を整える週" : "リズムの入りを整える週",
        focus: mode == :tempo_bias ? "参考テンポとのズレも目安にしながら、歌い始めと語尾のタイミングをクリックに合わせて整えましょう。" : "歌い始めと語尾のタイミングをクリックに合わせて、流れの安定を作りましょう。",
        encouragement: "リズムが整うだけで、歌全体のまとまりはぐっと良くなります。"
      }
    when :expression_score
      {
        key: key,
        theme: "表現の幅を育てる週",
        focus: "強弱や抑揚を大きくしすぎず、まずは一番伝えたい一行から差をつけてみましょう。",
        encouragement: "小さな抑揚でも、言葉の届き方はしっかり変わっていきます。"
      }
    else
      {
        key: key,
        theme: "声の土台を整える週",
        focus: "今週は出しやすい音域で安定感を優先し、無理なく再現できる感覚を増やしましょう。",
        encouragement: "基礎が整うほど、次の変化も診断で見えやすくなります。"
      }
    end
  end

  def singing_weekly_guitar_coach_copy(key, mode)
    case key.to_sym
    when :attack_score
      {
        key: key,
        theme: mode == :recovery ? "アタックを立て直す週" : "アタックを整える週",
        focus: "音の出だしをそろえて、フレーズの輪郭が前に出る感覚を優先して確認しましょう。",
        encouragement: "出だしが整うだけで、ギター全体の説得力はかなり上がります。"
      }
    when :muting_score
      {
        key: key,
        theme: mode == :recovery ? "余韻を整理し直す週" : "ミュートを整える週",
        focus: "鳴らす音と止める音を分けて、不要な響きが残りすぎない流れを作りましょう。",
        encouragement: "余韻が整うと、音の抜け方が一気に洗練されて聴こえます。"
      }
    when :stability_score
      {
        key: key,
        theme: mode == :recovery ? "安定感を戻す週" : "安定感を積み上げる週",
        focus: "同じフレーズを何度か録音して、音量とタイミングの再現性を高めましょう。",
        encouragement: "安定感が増すほど、アタックや音色の良さも前に出しやすくなります。"
      }
    else
      {
        key: key,
        theme: mode == :tempo_bias ? "テンポ感を整える週" : "リズムの芯を整える週",
        focus: mode == :tempo_bias ? "参考テンポとのズレも目安にしながら、クリックに合わせてピッキング位置と音の長さをそろえましょう。" : "クリックに合わせて、ピッキング位置と音の長さをそろえることを優先しましょう。",
        encouragement: "リズムの土台が整うと、演奏全体の完成度が一段上がります。"
      }
    end
  end

  def singing_weekly_bass_coach_copy(key, mode)
    case key.to_sym
    when :groove_score
      {
        key: key,
        theme: mode == :recovery ? "グルーヴを立て直す週" : "グルーヴを整える週",
        focus: mode == :tempo_bias ? "参考テンポとのズレも目安にしながら、拍の頭と音の出だしを近づけて低音の流れを整えましょう。" : "拍の頭と音の出だしを近づけて、低音が前へ進む流れを作ることを優先しましょう。",
        encouragement: "ノリが整うと、ベースの土台感はかなり強く伝わるようになります。"
      }
    when :note_length_score
      {
        key: key,
        theme: mode == :recovery ? "音価を揃え直す週" : "音価を整える週",
        focus: "伸ばす音と切る音の長さをそろえて、フレーズの説得力を上げることを意識しましょう。",
        encouragement: "音の長さが揃うだけで、ベースラインの気持ちよさはぐっと増していきます。"
      }
    when :stability_score
      {
        key: key,
        theme: mode == :recovery ? "土台感を戻す週" : "安定感を積み上げる週",
        focus: "タイミングと音量の揺れを小さくして、低音の支え方を安定させましょう。",
        encouragement: "安定感が増すほど、バンド全体を前に進める力が出てきます。"
      }
    else
      {
        key: key,
        theme: "ベースの土台を整える週",
        focus: "今週は短いフレーズで入りと長さをそろえ、低音のまとまりを育てていきましょう。",
        encouragement: "土台が整うほど、グルーヴも音価も自然に伸ばしやすくなります。"
      }
    end
  end

  def singing_weekly_drums_coach_copy(key, mode)
    case key.to_sym
    when :tempo_stability_score
      {
        key: key,
        theme: mode == :recovery ? "テンポ感を立て直す週" : "テンポ安定を整える週",
        focus: mode == :tempo_bias ? "参考テンポとの差も目安にしながら、ビートの土台を崩さず一定の流れを体に入れていきましょう。" : "ビートの土台を崩さないことを最優先にして、一定の流れを体に入れていきましょう。",
        encouragement: "テンポの安心感が出るだけで、ドラム全体の信頼感は大きく変わります。"
      }
    when :rhythm_precision_score, :rhythm_score
      {
        key: key,
        theme: mode == :recovery ? "リズム精度を戻す週" : "リズム精度を整える週",
        focus: "叩きの粒をそろえて、同じパターンでも芯がぶれない状態を目指しましょう。",
        encouragement: "粒がそろってくると、ビートの強さはかなりはっきり伝わります。"
      }
    when :dynamics_score, :expression_score
      {
        key: key,
        theme: mode == :recovery ? "ダイナミクスを整え直す週" : "強弱を育てる週",
        focus: "大きさの差をつけるより先に、狙った強さを再現できることを意識しましょう。",
        encouragement: "強弱が整うほど、演奏の立体感は自然に出てきます。"
      }
    when :fill_control_score
      {
        key: key,
        theme: mode == :recovery ? "フィルの流れを戻す週" : "フィルを自然につなぐ週",
        focus: "フィル後の1拍目を安定させて、展開が流れを止めない形を作りましょう。",
        encouragement: "戻りが整うと、フィルは見せ場としてかなり映えるようになります。"
      }
    else
      {
        key: key,
        theme: "ビートの土台を整える週",
        focus: "今週はシンプルなパターンで、テンポと粒の安定を優先して積み上げましょう。",
        encouragement: "土台が整うほど、ダイナミクスやフィルも伸ばしやすくなります。"
      }
    end
  end

  def singing_weekly_keyboard_coach_copy(key, mode)
    case key.to_sym
    when :chord_stability_score
      {
        key: key,
        theme: mode == :recovery ? "コード安定を立て直す週" : "和音のまとまりを整える週",
        focus: "コードチェンジ直後の響きが崩れすぎないように、和音のまとまりを優先しましょう。",
        encouragement: "和音が整うだけで、伴奏全体の安心感はかなり上品に伝わります。"
      }
    when :note_connection_score
      {
        key: key,
        theme: mode == :recovery ? "音のつながりを戻す週" : "フレーズをなめらかにする週",
        focus: "ぶつ切り感を減らして、次の音へ自然につながる流れを少しずつ作りましょう。",
        encouragement: "つながりが整うほど、キーボード全体が自然で聴きやすくなります。"
      }
    when :touch_score
      {
        key: key,
        theme: mode == :recovery ? "タッチを整え直す週" : "タッチを磨く週",
        focus: "打鍵の強さをそろえて、音の粒が跳ねすぎないことを今週の優先テーマにしましょう。",
        encouragement: "タッチが整うと、響きもかなり上品にまとまってきます。"
      }
    when :harmony_score
      {
        key: key,
        theme: mode == :recovery ? "響きのまとまりを戻す週" : "ハーモニーを整える週",
        focus: "和音の重なり方を聴きながら、濁りすぎないバランスを確認しましょう。",
        encouragement: "響きが整うほど、伴奏としての支え方がぐっと自然になります。"
      }
    when :rhythm_score
      {
        key: key,
        theme: mode == :tempo_bias ? "テンポ感を整える週" : "リズムの流れを整える週",
        focus: mode == :tempo_bias ? "参考テンポとの差も目安にしながら、音のつながりを保って入りのタイミングをそろえましょう。" : "音のつながりを保ちながら、入りのタイミングが前後しすぎないことを意識しましょう。",
        encouragement: "リズムが整うと、キーボード全体の自然さはかなり増していきます。"
      }
    when :expression_score
      {
        key: key,
        theme: "表情の幅を育てる週",
        focus: "強弱を大きくつける前に、狙ったニュアンスを丁寧に再現できることを優先しましょう。",
        encouragement: "タッチと表情がつながると、響きの魅力はもっと前に出てきます。"
      }
    when :pitch_score
      {
        key: key,
        theme: "音の選び方を整える週",
        focus: "和音や単音の響きを確認しながら、ぶつかりや濁りが強すぎない流れを意識しましょう。",
        encouragement: "音の置き方が整うほど、ハーモニーの安心感も育てやすくなります。"
      }
    else
      {
        key: key,
        theme: "キーボードの土台を整える週",
        focus: "今週は和音・つながり・タッチのどれも崩しすぎないよう、丁寧さを優先して弾きましょう。",
        encouragement: "基礎が整うほど、ハーモニーの美しさも安定して出しやすくなります。"
      }
    end
  end

  def singing_weekly_band_coach_copy(key, mode)
    case key.to_sym
    when :ensemble_score, :cohesion
      {
        key: key,
        theme: mode == :recovery ? "全体の一体感を立て直す週" : "リズム隊を中心に一体感を作る週",
        focus: "短い区間で全員の入り方と重なり方をそろえ、バンドとしてひとつに聴こえる状態を優先しましょう。",
        goal: "全員が同じ拍感とセクション感を共有し、通したときに演奏が一つの塊として聴こえること。",
        studio_steps: [
          "まず4〜8小節だけを繰り返し、ドラムとベースの重なりをそろえる",
          "ギター・キーボード・ボーカルを足して、どこでまとまりが崩れるかを確認する",
          "最後に全員で録音し、入りのズレやブレイク後の戻りを聴き直す"
        ],
        recording_points: [
          "曲の頭やサビ頭で全員の入りがそろっているか",
          "ブレイクやキメの後に戻るタイミングがばらついていないか",
          "演奏全体が一つの流れとして聴こえるか"
        ],
        homework: "各パートごとに、次回合わせで特に合わせ直したい8小節を1つ決めてきましょう。",
        encouragement: "噛み合いが整うだけで、個々の良さもかなり自然に伝わりやすくなります。"
      }
    when :role_understanding_score, :role_clarity
      {
        key: key,
        theme: mode == :recovery ? "各パートの役割を見直す週" : "各パートの役割を整理する週",
        focus: "誰が前に出る場面か、誰が支える場面かを共有して、音の住み分けをはっきりさせましょう。",
        goal: "Aメロ・サビ・間奏で、主役と支え役が全員に共有されている状態を作ること。",
        studio_steps: [
          "セクションごとに主役のパートと支えるパートを書き出す",
          "全員で1コーラス合わせ、同時に前へ出すぎる音を減らす",
          "録音を聴きながら、主役が変わる場面で伴奏の引き方を調整する"
        ],
        recording_points: [
          "主旋律や印象的なフレーズが埋もれていないか",
          "同じ帯域に音が重なりすぎていないか",
          "サビで全員が前に出すぎていないか"
        ],
        homework: "各パートごとに『自分が前に出る場所』と『支える場所』を1つずつ決めてきましょう。",
        encouragement: "役割が見えるほど、バンド全体の見通しはかなり良くなります。"
      }
    when :volume_balance_score, :balance
      {
        key: key,
        theme: mode == :recovery ? "音量バランスを立て直す週" : "ボーカルが聴こえる音量バランスを作る週",
        focus: "主役が自然に聴こえるバランスを基準にして、出過ぎる音と埋もれる音を整理しましょう。",
        goal: "全員が『自分の音を出す』ではなく、『曲として聴こえる音量』に整えること。",
        studio_steps: [
          "まずドラムとベースだけで1コーラス合わせる",
          "そこにギター・キーボードを足して、ボーカルや主旋律が聴こえる音量まで下げる",
          "最後に全員で録音して、誰の音が前に出すぎているか確認する"
        ],
        recording_points: [
          "ボーカルや主旋律が埋もれていないか",
          "低音が膨らみすぎていないか",
          "サビで全員が同時に大きくなりすぎていないか"
        ],
        homework: "各パートごとに、今の持ち音量より一段下げても成立する演奏感を試してきましょう。",
        encouragement: "音量差が整うだけで、演奏の聴きやすさは一段上がります。"
      }
    when :groove_score, :groove
      {
        key: key,
        theme: mode == :recovery ? "ノリを立て直す週" : "ノリ・推進力を整える週",
        focus: "前ノリ・後ノリの感じ方をそろえて、リズム隊を軸にバンド全体のノリを共有しましょう。",
        goal: "リズム隊の重心をそろえたうえで、全員が同じ推進力で曲を前に進められること。",
        studio_steps: [
          "ドラムとベースだけで1コーラス合わせ、ノリの軸を決める",
          "ほかのパートを足しながら、前ノリ・後ノリの感じ方をすり合わせる",
          "サビ前後を録音して、曲が前に進んで聴こえるかを確認する"
        ],
        recording_points: [
          "ベースとドラムの重心がそろっているか",
          "伴奏がリズム隊のノリを邪魔していないか",
          "サビで推進力が自然に上がっているか"
        ],
        homework: "各パートごとに、原曲や参考音源を聴いて『前に進む瞬間』を1つ言葉にしてきましょう。",
        encouragement: "ノリがそろうほど、演奏の推進力はかなり強く伝わるようになります。"
      }
    when :dynamics_score, :dynamics, :expression_score
      {
        key: key,
        theme: mode == :recovery ? "曲展開を立て直す週" : "Aメロとサビのダイナミクス差を作る週",
        focus: "どこで抑えてどこで広げるかを共有して、曲の展開が伝わる強弱差を作りましょう。",
        goal: "Aメロ・Bメロ・サビで、全員が同じ展開イメージを持って抑揚をつけられること。",
        studio_steps: [
          "Aメロ・Bメロ・サビごとに、どこまで音量差をつけるか決める",
          "サビ前のキメやブレイクで、抑えてから広げる流れを確認する",
          "録音して、展開差が聴き手に伝わるかを全員で聴き直す"
        ],
        recording_points: [
          "Aメロとサビでしっかり空気感の差が出ているか",
          "ブレイク後の戻りが急すぎたり弱すぎたりしないか",
          "強くする場面で音が混みすぎていないか"
        ],
        homework: "各パートごとに、曲中で『抑える場所』と『広げる場所』を1つずつ決めてきましょう。",
        encouragement: "全員の強弱がそろうと、同じフレーズでもかなり立体的に聴こえます。"
      }
    when :rhythm_unity_score, :tightness, :rhythm_score
      {
        key: key,
        theme: mode == :tempo_bias ? "キメ・ブレイクのタイミングを揃える週" : "リズム隊を中心に一体感を作る週",
        focus: mode == :tempo_bias ? "参考テンポとの差も目安にしながら、クリックやドラムに対する全員の入り方をそろえましょう。" : "クリックやドラムに対する全員の入り方をそろえ、拍の感じ方を共有しましょう。",
        goal: "ドラムとベースを基準に、伴奏と歌の入りが同じ拍感でそろうこと。",
        studio_steps: [
          "ドラムとベースだけで1コーラス合わせ、拍の頭をそろえる",
          "ギター・キーボード・ボーカルを足して、キメやブレイク前後の入りを確認する",
          "難しい8小節を録音して、誰が前後しているかを全員で確認する"
        ],
        recording_points: [
          "ドラムとベースの頭がそろっているか",
          "キメやブレイク後の戻りがばらついていないか",
          "歌や伴奏の入りが拍より前後しすぎていないか"
        ],
        homework: "各パートごとに、入り直しが難しい箇所を1つ決めて、個別にカウントを確認してきましょう。",
        encouragement: "リズムの揃いが整うだけで、バンド全体の安心感はぐっと増していきます。"
      }
    else
      {
        key: key,
        theme: "バンドのまとまりを整える週",
        focus: "今週は短い区間に絞り、噛み合い・音量差・ノリをひとつずつそろえていきましょう。",
        goal: "短い区間での改善を積み上げて、通したときのまとまりを上げること。",
        studio_steps: [
          "気になる8小節だけを繰り返して合わせる",
          "録音して、噛み合い・音量差・ノリを順番に見直す",
          "修正後にもう一度通して、改善したか確認する"
        ],
        recording_points: [
          "演奏全体のまとまりが増したか",
          "パートごとの出過ぎ・引きすぎが減ったか",
          "修正前後で聴こえ方が変わったか"
        ],
        homework: "次回までに、各パートで一番気になったポイントを1つずつ共有できるよう整理してきましょう。",
        encouragement: "土台が整うほど、各パートの魅力も自然に活きてきます。"
      }
    end
  end

  def singing_band_weekly_coach_quality_note(diagnosis)
    flags = singing_band_quality_flags(diagnosis)
    return nil unless ActiveModel::Type::Boolean.new.cast(flags[:low_confidence] || flags["low_confidence"])

    "今回の診断は参考値として扱い、まずは30秒以上の録音で再診断することもおすすめです。"
  end

  def singing_weekly_coach_tempo_reference_note(diagnosis, reference)
    tempo_level = reference[:tempo_match_level] || reference["tempo_match_level"]
    return nil if tempo_level.blank?

    reference_bpm = reference[:reference_bpm] || reference["reference_bpm"]
    estimated_bpm = reference[:estimated_bpm] || reference["estimated_bpm"]
    bpm_diff = reference[:bpm_diff] || reference["bpm_diff"]
    direction = singing_weekly_coach_tempo_direction(reference_bpm, estimated_bpm)
    direction_text = case direction
                     when :faster then "少し速くなりやすい"
                     when :slower then "少し遅くなりやすい"
                     else "少し揺れやすい"
                     end
    diff_text = bpm_diff.present? ? "（差の目安: #{bpm_diff} BPM）" : ""

    case tempo_level.to_s
    when "far", "moderate", "near"
      prefix = case diagnosis.performance_type.to_s
               when "bass" then "曲基準メモ：参考として、今はグルーヴが#{direction_text}傾向があります#{diff_text}。"
               when "drums" then "曲基準メモ：参考として、今はテンポ感が#{direction_text}可能性があります#{diff_text}。"
               else "曲基準メモ：参考として、今は原曲テンポより#{direction_text}可能性があります#{diff_text}。"
               end

      suffix = case diagnosis.performance_type.to_s
               when "bass" then "今週は拍の頭と音の出だしをそろえて、ノリの安定もあわせて確認してみましょう。"
               when "drums" then "今週はクリックに対する入りと戻りをそろえて、テンポの土台を整えてみましょう。"
               else "今週はクリックや原曲に合わせて、入りのタイミングを無理なくそろえてみましょう。"
               end

      "#{prefix} #{suffix}"
    when "close", "exact"
      "曲基準メモ：テンポはおおむね合っています。今週は今の流れを保ちながら、テーマの項目を優先して磨いていきましょう。"
    else
      nil
    end
  end

  def singing_weekly_coach_key_reference_note(diagnosis, reference)
    key_level = reference[:key_match_level] || reference["key_match_level"]
    return nil if key_level.blank?

    reference_key = reference[:reference_key] || reference["reference_key"]
    estimated_key = reference[:estimated_key] || reference["estimated_key"]
    keys_text = if reference_key.present? || estimated_key.present?
                  "（参考キー: #{reference_key || '-'} / 推定キー: #{estimated_key || '推定不可'}）"
                end

    case key_level.to_s
    when "far", "unknown"
      case diagnosis.performance_type.to_s
      when "vocal"
        "曲基準メモ：キーはまだ揺れやすい可能性があります#{keys_text}。目安では、原曲キーやガイド音で入りの音程を確認すると今週のテーマが定着しやすくなります。"
      when "keyboard"
        "曲基準メモ：キーや和音のまとまりはまだ確認の余地がありそうです#{keys_text}。目安では、コードの響きとチェンジ直後の安定をゆっくり確認してみましょう。"
      when "guitar", "bass"
        "曲基準メモ：音選びやポジション感はまだ揺れやすい可能性があります#{keys_text}。参考として、原曲キーに対する狙いどころをゆっくり確認してみましょう。"
      when "band"
        "曲基準メモ：調和やコードの噛み合いはまだ確認の余地がありそうです#{keys_text}。参考として、和音の重なりと各パートの音域のぶつかり方をゆっくり確認してみましょう。"
      else
        nil
      end
    when "close", "exact"
      "曲基準メモ：キーはおおむね合っています#{keys_text}。今週は音程や和音の大きなズレを気にしすぎず、テーマの項目を優先して大丈夫です。"
    else
      nil
    end
  end

  def singing_weekly_coach_tempo_direction(reference_bpm, estimated_bpm)
    return nil unless reference_bpm.present? && estimated_bpm.present?

    reference_value = reference_bpm.to_f
    estimated_value = estimated_bpm.to_f
    return nil if reference_value.zero? || estimated_value.zero?

    return :faster if estimated_value > reference_value
    return :slower if estimated_value < reference_value

    :same
  end

  def bass_groove_practice_menu
    {
      title: "拍頭をそろえるグルーヴ確認",
      target: "グルーヴ",
      description: "短いベースラインを繰り返し、拍の頭と音の出だしが近づく感覚を録音で確認します。"
    }
  end

  def bass_note_length_practice_menu
    {
      title: "音価そろえ練習",
      target: "音価",
      description: "伸ばす音と切る音の長さを決めて、同じフレーズでも長さがぶれないように整えます。"
    }
  end

  def bass_stability_practice_menu
    {
      title: "低音の土台づくり反復",
      target: "安定感",
      description: "同じフレーズを数回録音し、音量とタイミングの揺れが少ない弾き方を探します。"
    }
  end

  def vocal_volume_practice_menu
    {
      title: "響きを前に出す練習",
      target: "声量",
      description: "無理に強く押し出さず、響きが前に集まる位置を探して同じフレーズを安定させます。"
    }
  end

  def vocal_pronunciation_practice_menu
    {
      title: "言葉の頭をそろえる練習",
      target: "発音",
      description: "歌詞の最初の子音と母音のつながりを確認し、言葉が自然に届く流れを整えます。"
    }
  end

  def vocal_relax_practice_menu
    {
      title: "力みを抜く呼吸練習",
      target: "リラックス",
      description: "出しやすい高さで息の流れを保ち、喉や肩まわりに余計な力が入らない状態を探します。"
    }
  end

  def vocal_mix_voice_practice_menu
    {
      title: "高音のつながり確認",
      target: "ミックスボイス",
      description: "地声と裏声の切り替わりが急になりすぎないよう、ゆっくり音をつないで確認します。"
    }
  end

  def singing_premium_type_diagnosis_configs(diagnosis)
    case diagnosis.performance_type.to_s
    when "guitar"
      [
        premium_type_config(
          label: "発音の輪郭",
          title: "音の出だしで前に出る力",
          score_key: :attack_score,
          high: ["立ち上がりがはっきりしていて、フレーズの輪郭が前に出やすい状態です。", "音の芯が見えやすく、リフや単音フレーズの意図が伝わりやすいです。", "強く弾く箇所だけに頼ると、弱い音との粒差が出やすくなります。", "弱めの音でも出だしをそろえ、ニュアンスの幅を広げましょう。"],
          middle: ["音の輪郭は見えていますが、入りの粒に少し差が出やすい状態です。", "土台はあるので、入りを整えるだけで演奏の説得力が上がりやすいです。", "フレーズによって発音がぼやけると、リズムの芯も見えにくくなります。", "短いリフをゆっくり録音し、最初の1音の立ち上がりを確認しましょう。"],
          low: ["まずは音の出だしをそろえると、ギターらしい輪郭を作りやすくなります。", "伸ばすポイントが明確なので、短い反復でも変化を感じやすい領域です。", "発音が曖昧なままだと、良いフレーズも奥に引っ込みやすくなります。", "開放弦や単音で、同じ強さ・同じタイミングの発音を整えましょう。"]
        ),
        premium_type_config(
          label: "余韻の整理",
          title: "鳴らす音と止める音のコントロール",
          score_key: :muting_score,
          high: ["不要な響きが整理され、鳴らしたい音が見えやすい状態です。", "音の抜け方がすっきりし、フレーズ全体が洗練されて聴こえやすいです。", "余韻を短くしすぎると、伸ばしたい音の表情が薄くなることがあります。", "止める音と伸ばす音の差を意識して、立体感を作りましょう。"],
          middle: ["鳴らしたい音は見えていますが、余韻処理で少し濁りやすい箇所がありそうです。", "ミュートの意識が入るだけで、演奏の解像度が上がりやすい状態です。", "不要な響きが残ると、コードやリフの輪郭がぼやけやすくなります。", "休符前後だけを切り出し、音を止めるタイミングを録音で確認しましょう。"],
          low: ["不要な残響を整理すると、演奏全体がかなり聴き取りやすくなる余地があります。", "ミュートは改善が音に出やすく、短い練習でも効果を確認しやすいです。", "鳴らしたくない音が混ざると、リズムやコード感まで曖昧に聴こえやすくなります。", "2〜3音の短いパターンで、弾いた後に止める動きを丁寧に確認しましょう。"]
        ),
        premium_type_config(
          label: "演奏の芯",
          title: "安定感が作る完成度",
          score_key: :stability_score,
          high: ["音量やタイミングがまとまり、演奏の芯が安定している状態です。", "土台があるため、表現や音色の作り込みに意識を向けやすくなっています。", "安定重視になりすぎると、勢いや表情が控えめになることがあります。", "安定感を保ったまま、アクセントや音の長さで表情を足しましょう。"],
          middle: ["演奏のまとまりはありますが、音量やタイミングに少し揺れが出る箇所がありそうです。", "基礎の方向は良く、テンポを落とすと完成度を上げやすい状態です。", "揺れが重なると、曲全体の推進力が少し弱く聴こえることがあります。", "同じフレーズを3回続けて録音し、再現性を確認しましょう。"],
          low: ["まずは音量とタイミングのばらつきを小さくすると、演奏の芯が作りやすくなります。", "短い範囲に絞れば、安定感の変化を確認しやすい状態です。", "不安定さが残ると、良い発音や音色も伝わりにくくなります。", "2〜4小節だけをゆっくり弾き、音量と入りをそろえましょう。"]
        )
      ]
    when "bass"
      [
        premium_type_config(
          label: "ノリの土台",
          title: "曲を前に進めるグルーヴ",
          score_key: :groove_score,
          high: ["リズムの流れが安定し、低音が曲全体を前に進めやすい状態です。", "ノリの軸があるため、ほかのパートと合わさった時の説得力が出やすいです。", "流れが良い分、細かな音価の違いが目立つ場合があります。", "良いノリを保ちながら、休符前後の入りをさらに整えましょう。"],
          middle: ["グルーヴの土台はありますが、音の入りに少し揺れが出やすい状態です。", "拍の感じ方は見えているので、短い反復でまとまりを作りやすいです。", "入りがばらつくと、低音の推進力が少し弱く聴こえます。", "キックやクリックに合わせ、拍の頭と音の出だしを近づけましょう。"],
          low: ["まずは拍の感じ方と音の入りを整えると、ベースの説得力が上がりやすいです。", "基礎を絞って練習すると、曲を支える感覚をつかみやすい領域です。", "ノリが不安定なままだと、他パートが乗りにくく聴こえることがあります。", "2小節のパターンを選び、一定の間隔で弾く練習から始めましょう。"]
        ),
        premium_type_config(
          label: "音価コントロール",
          title: "長さが作る説得力",
          score_key: :note_length_score,
          high: ["音の長さが整い、ベースラインの意図が伝わりやすい状態です。", "伸ばす音と切る音の差が見えやすく、曲の土台として安定しやすいです。", "長さが整っている分、表情の変化が少ないと平坦に聴こえる場合があります。", "音価を保ちながら、サビや区切りで少しだけ長さの表情をつけましょう。"],
          middle: ["音価の土台はありますが、短すぎる音や長く残る音が少し混ざりやすい状態です。", "長さがそろうだけで、低音の説得力がかなり上がりやすいです。", "音価のばらつきがあると、ノリは良くてもフレーズが散らばって聴こえます。", "同じフレーズを弾き、音を切る位置を録音で確認しましょう。"],
          low: ["まずは音の長さをそろえることで、ベースラインの輪郭を作りやすくなります。", "音価は意識した分だけ変化を確認しやすいポイントです。", "長さが不揃いだと、曲全体の土台が落ち着きにくくなります。", "1音ずつ、伸ばす長さと止めるタイミングをゆっくり確認しましょう。"]
        ),
        premium_type_config(
          label: "低音の支え",
          title: "安定感が作る土台感",
          score_key: :stability_score,
          high: ["音量とタイミングがまとまり、低音の支えとして安心感がある状態です。", "バンド全体の下を支える力が出やすく、演奏の芯が見えています。", "安定している分、抑揚が控えめになると存在感が薄くなることがあります。", "安定感を保ちつつ、要所で少しだけ音の強さを変えてみましょう。"],
          middle: ["低音の土台はありますが、音量やタイミングに少し揺れが出る箇所がありそうです。", "まとまりの方向は見えているため、短い反復で土台感を強めやすいです。", "揺れが重なると、曲全体の重心が少し不安定に聴こえます。", "テンポを落として、同じ音量で数回続けて弾けるか確認しましょう。"],
          low: ["まずは音量と入りのばらつきを小さくすると、低音の支えが作りやすくなります。", "改善テーマが明確なので、基礎練習の成果を感じやすい領域です。", "土台が揺れると、他パートの良さも支えにくくなります。", "短いベースラインを選び、音量と入りをそろえる練習から始めましょう。"]
        )
      ]
    when "drums"
      [
        premium_type_config(
          label: "テンポの支え",
          title: "ビートの安心感",
          score_key: :tempo_stability_score,
          high: ["ビートの土台が安定していて、演奏全体を安心して支えられる状態です。", "一定の流れがあることで、ほかのパートが乗りやすいビートを作りやすいです。", "安定重視で抑揚が少ないと、展開の熱量が伝わりにくい場合があります。", "安定感を保ちながら、セクションごとの強弱を少しつけましょう。"],
          middle: ["大きく崩れてはいませんが、一定の流れをさらにそろえるとまとまりやすい状態です。", "テンポ感の土台はあるため、クリック練習の効果が出やすいです。", "細かな揺れが重なると、バンド全体の推進力が弱くなることがあります。", "8小節だけを選び、拍の頭が前後しないか確認しましょう。"],
          low: ["まずは一定のテンポ感を保つ意識を持つと、演奏の説得力が上がりやすいです。", "短い範囲に絞るほど、テンポの変化をつかみやすい状態です。", "テンポが揺れると、良いフィルや強弱も流れから外れて聴こえやすくなります。", "クリックに合わせて、シンプルなビートをゆっくり安定させましょう。"]
        ),
        premium_type_config(
          label: "リズムの芯",
          title: "叩きの揃いが作る強さ",
          score_key: :rhythm_precision_score,
          high: ["叩きのタイミングがそろい、ビートの芯が見えやすい状態です。", "リズムの粒が整うことで、演奏全体に締まりが出やすくなります。", "精度が高い分、強弱が少ないと機械的に聴こえる場合があります。", "粒を保ちながら、アクセントの位置を意識しましょう。"],
          middle: ["リズムの芯はありますが、細かな粒に少し差が出やすい状態です。", "基礎は見えているので、1パートに絞ると精度を上げやすいです。", "粒が乱れると、ビートの説得力が少し弱く聴こえます。", "ハイハットだけ、スネアだけなど、音を絞って揃えましょう。"],
          low: ["まずは叩きの間隔と強さをそろえると、ビートの芯が作りやすくなります。", "リズム精度は反復で伸ばしやすく、変化を感じやすいポイントです。", "粒が散ると、テンポが合っていても不安定に聴こえやすくなります。", "シンプルな8ビートを遅めのテンポで録音しましょう。"]
        ),
        premium_type_config(
          label: "展開のまとまり",
          title: "強弱とフィルの自然さ",
          score_key: :fill_control_score,
          high: ["フィルや展開が流れに乗り、曲を自然に前へ進めやすい状態です。", "切り替わりのまとまりがあるため、演奏の見せ場が作りやすいです。", "まとまりが良い分、強弱の幅が少ないと展開が平坦に聴こえる場合があります。", "フィル前後の音量差を意識して、曲の山を作りましょう。"],
          middle: ["フィルの流れは見えていますが、着地や強弱に少し整理できる余地があります。", "方向性はあるため、フィル後の1拍目を整えるだけで印象が変わりやすいです。", "着地が曖昧だと、せっかくの展開が流れを止めてしまうことがあります。", "短いフィルを1つ選び、戻りの1拍目を録音で確認しましょう。"],
          low: ["まずはフィル後に自然に戻る感覚を作ると、演奏全体がまとまりやすくなります。", "改善点が明確なので、短いフィル練習でも効果を確認しやすいです。", "フィルで流れが乱れると、ビート全体の安心感が弱くなります。", "フィルを短くして、戻る場所を決めてから練習しましょう。"]
        )
      ]
    when "keyboard"
      [
        premium_type_config(
          label: "和音の安定",
          title: "伴奏を支えるまとまり",
          score_key: :chord_stability_score,
          high: ["和音のまとまりがあり、演奏全体に安心感がある状態です。", "コードの響きが安定しているため、伴奏として支える力が出やすいです。", "安定している分、音色や強弱の変化が少ないと平坦に聴こえる場合があります。", "コードチェンジの安定を保ちつつ、曲の山で響きの強さを調整しましょう。"],
          middle: ["和音の土台はありますが、押さえや切り替えで少し揺れやすい状態です。", "響きの方向は良いので、チェンジ直後を整えるだけでまとまりが出やすいです。", "切り替えの乱れが残ると、伴奏全体の安心感が少し薄くなります。", "2つのコードだけをゆっくり切り替え、響きが急に崩れないか確認しましょう。"],
          low: ["まずは和音のまとまりを意識すると、聴こえ方が整いやすくなります。", "コード安定は短い反復で変化が出やすいポイントです。", "響きが揺れると、メロディや歌を支える力が弱く聴こえます。", "気になるコードを長めに鳴らし、音のぶつかりや強すぎる音を確認しましょう。"]
        ),
        premium_type_config(
          label: "音のつながり",
          title: "フレーズを自然に流す力",
          score_key: :note_connection_score,
          high: ["音の移り方がなめらかで、フレーズの流れが自然に聴こえやすい状態です。", "ぶつ切り感が少なく、伴奏やメロディのラインがつながって伝わりやすいです。", "つながりを優先しすぎると、リズムの輪郭が少し甘くなる場合があります。", "つなぐ音と区切る音を分け、フレーズに呼吸を作りましょう。"],
          middle: ["音のつながりは見えていますが、箇所によって少し切れやすい状態です。", "土台はあるので、テンポを落とすと滑らかさを伸ばしやすいです。", "ぶつ切り感が残ると、演奏全体が少し硬く聴こえることがあります。", "短いフレーズで、前の音が消えるタイミングと次の音の入りを確認しましょう。"],
          low: ["まずは次の音へなめらかに移る感覚を作ると、演奏が自然に聴こえやすくなります。", "音の接続は意識した分だけ録音で変化を確認しやすいです。", "音が途切れすぎると、和音や伴奏の流れが伝わりにくくなります。", "テンポを落として、レガート気味に短いフレーズをつなげましょう。"]
        ),
        premium_type_config(
          label: "タッチと響き",
          title: "上品さを作る打鍵とハーモニー",
          score_key: :touch_score,
          high: ["打鍵の粒が整い、丁寧で上品な印象が出やすい状態です。", "音量の揃い方が良く、ハーモニーのまとまりも伝わりやすくなります。", "整っている分、曲の山で変化が少ないと控えめに聴こえる場合があります。", "粒を保ちながら、サビや見せ場で少し抑揚を足しましょう。"],
          middle: ["タッチの土台はありますが、強さに少し差が出やすい状態です。", "打鍵が整うと、演奏全体の品の良さがかなり出やすくなります。", "一部の音が強く出ると、和音のバランスが崩れて聴こえることがあります。", "同じフレーズを同じ強さで弾き、音量が跳ねないか録音しましょう。"],
          low: ["まずは打鍵の強さをそろえることで、キーボードらしいまとまりを作りやすくなります。", "タッチは短い練習で変化が出やすく、録音で確認しやすい項目です。", "強さのばらつきが大きいと、ハーモニーや伴奏の支え方も不安定に聴こえます。", "弱め・普通・少し強めを弾き分け、狙った強さを再現する練習をしましょう。"]
        )
      ]
    else
      []
    end
  end

  def premium_type_config(label:, title:, score_key:, high:, middle:, low:)
    {
      label: label,
      title: title,
      score_key: score_key,
      high: premium_type_band(*high),
      middle: premium_type_band(*middle),
      low: premium_type_band(*low)
    }
  end

  def premium_type_band(insight, strength, risk, next_theme)
    {
      insight: insight,
      strength: strength,
      risk: risk,
      next_theme: next_theme
    }
  end

  def singing_premium_type_comparison_note(diagnosis, score_key)
    comparison = diagnosis.specific_score_comparison if diagnosis.respond_to?(:specific_score_comparison)
    if comparison.present?
      values = comparison[score_key] || comparison[score_key.to_s]
      return if values.blank?

      delta = values[:delta] || values["delta"]
      return if delta.nil?
      return "前回より伸びています。この感覚を再現できると、演奏傾向として定着しやすくなります。" if delta.to_i.positive?
      return "前回と近い状態です。安定して出せている傾向として見てよさそうです。" if delta.to_i.zero?

      return "今回は前回より控えめに出ています。曲の難しさや録音条件も含めて、次回の確認ポイントにしましょう。"
    end

    reference = diagnosis.reference_comparison if diagnosis.respond_to?(:reference_comparison)
    return if reference.blank?

    tempo_match_level = reference[:tempo_match_level] || reference["tempo_match_level"]
    key_match_level = reference[:key_match_level] || reference["key_match_level"]
    return "曲のテンポ感にも近づいています。原曲との距離感を保ちながら、この良さを伸ばしていきましょう。" if tempo_match_level == "close"
    return "曲のキーやテンポとの距離がまだ揺れやすい可能性があります。原曲やクリックと合わせて確認すると、傾向をつかみやすくなります。" if key_match_level == "far" || tempo_match_level == "far"
  end

  def singing_drums_practice_menus(diagnosis)
    specific_scores = singing_specific_scores(diagnosis)
    menus = []

    menus << drums_tempo_practice_menu if specific_scores[:tempo_stability_score].to_i < 70
    menus << drums_precision_practice_menu if specific_scores[:rhythm_precision_score].to_i < 70
    menus << drums_dynamics_practice_menu if specific_scores[:dynamics_score].to_i < 70
    menus << drums_fill_practice_menu if specific_scores[:fill_control_score].to_i < 70

    if menus.empty?
      menus << drums_precision_practice_menu
      menus << drums_dynamics_practice_menu
    elsif diagnosis.overall_score.to_i >= 80 && menus.size < 3
      menus << drums_fill_practice_menu
    end

    menus.first(3)
  end

  def drums_tempo_practice_menu
    {
      title: "テンポキープ確認",
      target: "テンポ安定",
      description: "クリックに合わせて8小節だけ叩き、拍の頭が前後しすぎないか録音で確認しましょう。"
    }
  end

  def drums_precision_practice_menu
    {
      title: "リズム粒そろえ練習",
      target: "リズム精度",
      description: "ハイハットやスネアなど1つのパートに絞り、同じ強さ・同じ間隔で鳴らす感覚を整えましょう。"
    }
  end

  def drums_dynamics_practice_menu
    {
      title: "強弱コントロール練習",
      target: "ダイナミクス",
      description: "同じフレーズを小さめ・普通・大きめで叩き分け、曲の流れに合う強弱を探しましょう。"
    }
  end

  def drums_fill_practice_menu
    {
      title: "フィル着地確認",
      target: "フィル",
      description: "短いフィルを1つ選び、フィル後の1拍目へ自然に戻れるかをゆっくり確認しましょう。"
    }
  end

  def singing_keyboard_practice_menus(diagnosis)
    specific_scores = singing_specific_scores(diagnosis)
    menus = []

    menus << keyboard_chord_practice_menu if specific_scores.key?(:chord_stability_score) && specific_scores[:chord_stability_score].to_i < 70
    menus << keyboard_connection_practice_menu if specific_scores.key?(:note_connection_score) && specific_scores[:note_connection_score].to_i < 70
    menus << keyboard_touch_practice_menu if specific_scores.key?(:touch_score) && specific_scores[:touch_score].to_i < 70
    menus << keyboard_harmony_practice_menu if specific_scores.key?(:harmony_score) && specific_scores[:harmony_score].to_i < 70
    menus << keyboard_rhythm_practice_menu if diagnosis.rhythm_score.to_i < 70
    menus << keyboard_expression_practice_menu if diagnosis.expression_score.to_i < 70
    menus << keyboard_pitch_practice_menu if diagnosis.pitch_score.to_i < 70
    menus << keyboard_foundation_practice_menu if diagnosis.overall_score.to_i < 60

    if menus.empty?
      menus << keyboard_chord_practice_menu
      menus << keyboard_connection_practice_menu
    end

    menus.first(3)
  end

  def keyboard_chord_practice_menu
    {
      title: "コードチェンジ安定練習",
      target: "コード安定",
      description: "2つのコードだけを選び、ゆっくり切り替えながら、和音の響きが急に揺れないか確認しましょう。"
    }
  end

  def keyboard_connection_practice_menu
    {
      title: "フレーズ接続練習",
      target: "音のつながり",
      description: "短いフレーズをテンポを落として弾き、前の音が消えるタイミングと次の音の入りをなめらかにつなげましょう。"
    }
  end

  def keyboard_touch_practice_menu
    {
      title: "打鍵の粒そろえ練習",
      target: "タッチ",
      description: "同じフレーズを同じ強さで弾き、音量が急に跳ねたり沈んだりしないか録音で確認しましょう。"
    }
  end

  def keyboard_harmony_practice_menu
    {
      title: "和音バランス確認",
      target: "ハーモニー",
      description: "コードを長めに鳴らし、強すぎる音や埋もれる音がないかを聴きながら、伴奏として支える響きを整えましょう。"
    }
  end

  def keyboard_rhythm_practice_menu
    {
      title: "メトロノーム伴奏練習",
      target: "リズム",
      description: "メトロノームに合わせて短い伴奏パターンを弾き、コードの入りと次の音への移り方を拍にそろえましょう。"
    }
  end

  def keyboard_expression_practice_menu
    {
      title: "強弱づけ練習",
      target: "表現",
      description: "同じフレーズを弱め・普通・少し強めで弾き分け、曲の流れに合う抑揚を探しましょう。"
    }
  end

  def keyboard_pitch_practice_menu
    {
      title: "音選びと和音確認",
      target: "音程",
      description: "気になる小節だけをゆっくり弾き、選んだ音や和音の響きが曲の流れに合っているか確認しましょう。"
    }
  end

  def keyboard_foundation_practice_menu
    {
      title: "基礎優先ミニ練習",
      target: "全体の土台",
      description: "2〜4小節に絞り、コード安定・音のつながり・打鍵の強さをひとつずつ確認してから通して弾きましょう。"
    }
  end

  def singing_band_practice_menus(diagnosis)
    specific_scores = singing_specific_scores(diagnosis)
    menus = []

    menus << band_ensemble_practice_menu if specific_scores[:ensemble_score].to_i < 70
    menus << band_role_practice_menu if specific_scores[:role_understanding_score].to_i < 70
    menus << band_balance_practice_menu if specific_scores[:volume_balance_score].to_i < 70
    menus << band_rhythm_practice_menu if diagnosis.rhythm_score.to_i < 70 || specific_scores[:rhythm_unity_score].to_i < 70
    menus << band_groove_practice_menu if specific_scores[:groove_score].to_i < 70
    menus << band_dynamics_practice_menu if diagnosis.expression_score.to_i < 70 || specific_scores[:dynamics_score].to_i < 70
    menus << band_cohesion_practice_menu if diagnosis.overall_score.to_i < 60 || specific_scores[:cohesion_score].to_i < 70

    if menus.empty?
      menus << band_ensemble_practice_menu
      menus << band_balance_practice_menu
    end

    menus.first(3)
  end

  def band_ensemble_practice_menu
    {
      title: "短区間アンサンブル確認",
      target: "アンサンブル力",
      description: "4〜8小節だけを繰り返し、全員の入り方と音の重なりがそろうかを録音で確認しましょう。"
    }
  end

  def band_role_practice_menu
    {
      title: "役割分担の見直し",
      target: "役割理解",
      description: "セクションごとに主役と支え役を決め、誰が前に出る場面かを共有してから合わせ直します。"
    }
  end

  def band_balance_practice_menu
    {
      title: "音量バランス調整",
      target: "音量バランス",
      description: "全員で一段小さめの音量に合わせ、主役の音が自然に聴こえる位置まで必要なパートだけを足していきます。"
    }
  end

  def band_rhythm_practice_menu
    {
      title: "拍感そろえ練習",
      target: "リズムの揃い",
      description: "クリックかドラムを基準にして、全員の入りと戻りが前後しすぎないかを短い区間で確認します。"
    }
  end

  def band_groove_practice_menu
    {
      title: "ノリ共有リハーサル",
      target: "グルーヴ",
      description: "前ノリか後ノリかの感じ方を合わせ、リズム隊の重心にほかのパートがどう乗るかを確認します。"
    }
  end

  def band_dynamics_practice_menu
    {
      title: "展開ごとの強弱整理",
      target: "ダイナミクス",
      description: "Aメロ・Bメロ・サビごとに音量の目安を共有し、曲の流れに合う強弱差をそろえましょう。"
    }
  end

  def band_cohesion_practice_menu
    {
      title: "全体まとまり確認",
      target: "全体のまとまり",
      description: "気になる8小節を録音し、噛み合い・音量差・ノリを順番に見直してから通して合わせましょう。"
    }
  end

  def singing_feedback_score(diagnosis, score_key)
    score = diagnosis.public_send(score_key) if diagnosis.respond_to?(score_key)
    normalized_score = singing_normalize_score(score)
    return normalized_score unless normalized_score.nil?

    payload = diagnosis.respond_to?(:result_payload) ? diagnosis.result_payload : nil
    return unless payload.respond_to?(:[])

    specific_score = if payload.respond_to?(:dig)
                       payload.dig(:specific, score_key) ||
                         payload.dig(:specific, score_key.to_s) ||
                         payload.dig("specific", score_key) ||
                         payload.dig("specific", score_key.to_s)
                     end

    singing_normalize_score(
      payload[score_key] ||
      payload[score_key.to_s] ||
      specific_score
    )
  end

  def singing_normalize_score(value, clamp: true)
    return nil if value.nil?
    return [[value.round, 0].max, 100].min if value.is_a?(Numeric) && clamp
    return value.round if value.is_a?(Numeric)

    normalized = value.to_s.strip
    return nil if normalized.blank?

    parsed_value = begin
      Float(normalized)
    rescue ArgumentError, TypeError
      nil
    end
    return nil if parsed_value.nil?

    rounded_value = parsed_value.round
    return [[rounded_value, 0].max, 100].min if clamp

    rounded_value
  end

  def singing_normalize_delta(value)
    singing_normalize_score(value, clamp: false)
  end

  def singing_band_analysis_debug_payload(diagnosis)
    payload = diagnosis.respond_to?(:result_payload) ? diagnosis.result_payload : nil
    return {} unless payload.respond_to?(:[])

    singing_band_analysis_debug_hash(payload[:analysis_debug] || payload["analysis_debug"])
  end

  def singing_band_analysis_debug_hash(value)
    value.respond_to?(:[]) ? value : {}
  end

  def singing_band_payload_check_item(payload, path, label:)
    keys = Array(path)
    value = singing_band_payload_dig(payload, keys)
    present = !value.nil?

    {
      label: label,
      present: present,
      message: present ? "✅ #{label}" : "⚠️ missing: #{label}"
    }
  end

  def singing_band_payload_dig(payload, keys)
    current = payload

    keys.each do |key|
      return nil unless current.respond_to?(:[])

      if current.respond_to?(:key?)
        if current.key?(key)
          current = current[key]
        elsif current.key?(key.to_s)
          current = current[key.to_s]
        elsif current.key?(key.to_sym)
          current = current[key.to_sym]
        else
          return nil
        end
      else
        current = current[key] || current[key.to_s] || current[key.to_sym]
      end
    end

    current
  end

  def singing_band_analysis_debug_metric(source, key, precision: 6)
    value = singing_band_analysis_debug_number(source[key] || source[key.to_s])
    return "-" if value.nil?

    format("%.#{precision}f", value)
  end

  def singing_band_analysis_debug_integer_metric(source, key)
    value = singing_band_analysis_debug_number(source[key] || source[key.to_s], integer: true)
    value.nil? ? "-" : value.to_s
  end

  def singing_band_analysis_debug_number(value, integer: false)
    return nil if value.nil?
    return value.to_i if integer && value.is_a?(Numeric)
    return value.to_f if value.is_a?(Numeric)

    normalized = value.to_s.strip
    return nil if normalized.blank?

    parsed_value = begin
      Float(normalized)
    rescue ArgumentError, TypeError
      nil
    end
    return nil if parsed_value.nil?

    integer ? parsed_value.round : parsed_value
  end

  def singing_advanced_feedback_targets(diagnosis)
    return GUITAR_ADVANCED_FEEDBACK_TARGETS if diagnosis.performance_type_guitar?
    return BASS_ADVANCED_FEEDBACK_TARGETS if diagnosis.performance_type_bass?
    return DRUMS_ADVANCED_FEEDBACK_TARGETS if diagnosis.performance_type_drums?
    return KEYBOARD_ADVANCED_FEEDBACK_TARGETS if diagnosis.performance_type_keyboard?
    return BAND_ADVANCED_FEEDBACK_TARGETS if diagnosis.performance_type_band?

    ADVANCED_FEEDBACK_TARGETS
  end

  def singing_radar_chart_configs(diagnosis)
    if diagnosis.performance_type_vocal?
      [
        { key: :pitch_score, label: "音程" },
        { key: :rhythm_score, label: "リズム" },
        { key: :expression_score, label: "表現" }
      ]
    elsif diagnosis.performance_type_guitar?
      [
        { key: :rhythm_score, label: "リズム" },
        { key: :expression_score, label: "表現" },
        { key: :attack_score, label: "アタック" },
        { key: :muting_score, label: "ミュート" },
        { key: :stability_score, label: "安定感" }
      ]
    elsif diagnosis.performance_type_bass?
      [
        { key: :rhythm_score, label: "リズム" },
        { key: :expression_score, label: "表現" },
        { key: :groove_score, label: "グルーヴ" },
        { key: :note_length_score, label: "音価" },
        { key: :stability_score, label: "安定感" }
      ]
    elsif diagnosis.performance_type_keyboard?
      [
        { key: :pitch_score, label: "音程" },
        { key: :rhythm_score, label: "リズム" },
        { key: :expression_score, label: "表現" },
        { key: :chord_stability_score, label: "コード安定" },
        { key: :note_connection_score, label: "音のつながり" },
        { key: :touch_score, label: "タッチ" },
        { key: :harmony_score, label: "ハーモニー" }
      ]
    elsif diagnosis.performance_type_band?
      [
        { key: :pitch_score, label: "調和" },
        { key: :rhythm_score, label: "リズムの揃い" },
        { key: :expression_score, label: "ダイナミクス" },
        { key: :role_understanding_score, label: "役割理解" },
        { key: :volume_balance_score, label: "音量バランス" },
        { key: :groove_score, label: "グルーヴ" },
        { key: :cohesion_score, label: "全体のまとまり" }
      ]
    else
      []
    end
  end

  def singing_radar_score(diagnosis, score_key)
    score = diagnosis.public_send(score_key) if diagnosis.respond_to?(score_key)
    normalized_score = singing_normalize_score(score)
    return normalized_score unless normalized_score.nil?

    singing_normalize_score(singing_specific_scores(diagnosis)[score_key])
  end

  def singing_feedback_band(score)
    value = singing_normalize_score(score) || 0
    return :high if value >= 80
    return :middle if value >= 60

    :low
  end

  def premium_check_item(label, description, score)
    normalized_score = singing_normalize_score(score) || 0

    {
      label: label,
      description: description,
      score: normalized_score,
      rating: premium_rating(normalized_score),
      comment: premium_rating_comment(normalized_score)
    }
  end

  def premium_average_score(*scores)
    values = scores.filter_map { |score| singing_normalize_score(score) }
    return 0 if values.empty?

    (values.sum.to_f / values.size).round
  end

  def premium_rating(score)
    value = score.to_i
    return 5 if value >= 85
    return 4 if value >= 70
    return 3 if value >= 55
    return 2 if value >= 40

    1
  end

  def premium_rating_comment(score)
    case premium_rating(score)
    when 5
      "かなり良い状態です。強みとして活かしやすい項目です。"
    when 4
      "安定感があります。少し整えるとさらに魅力が出やすい項目です。"
    when 3
      "土台はあります。練習で変化を作りやすい項目です。"
    when 2
      "伸ばしどころがあります。短いフレーズで丁寧に確認しましょう。"
    else
      "まずは無理なく感覚をつかむところから始めるとよさそうです。"
    end
  end

  def growth_chart_label(diagnosis)
    created_at = diagnosis.respond_to?(:created_at) ? diagnosis.created_at : nil
    return "今回" if created_at.blank?

    created_at.strftime("%m/%d")
  end

  def specific_growth_chart_color(key, performance_type = nil)
    palette = case performance_type.to_s
              when "guitar"
                {
                  attack_score: "#ea580c",
                  muting_score: "#dc2626",
                  stability_score: "#b45309"
                }
              when "bass"
                {
                  groove_score: "#7c3aed",
                  note_length_score: "#0f766e",
                  stability_score: "#4338ca"
                }
              when "drums"
                {
                  tempo_stability_score: "#2563eb",
                  rhythm_precision_score: "#7c3aed",
                  dynamics_score: "#ea580c",
                  fill_control_score: "#dc2626"
                }
              when "keyboard"
                {
                  chord_stability_score: "#0f766e",
                  note_connection_score: "#2563eb",
                  touch_score: "#7c3aed",
                  harmony_score: "#ea580c"
                }
              when "band"
                {
                  ensemble_score: "#0f766e",
                  harmony_score: "#2563eb",
                  role_understanding_score: "#7c3aed",
                  volume_balance_score: "#ea580c",
                  rhythm_unity_score: "#dc2626",
                  groove_score: "#059669",
                  dynamics_score: "#d97706",
                  cohesion_score: "#334155"
                }
              else
                {
                  volume_score: "#0f766e",
                  pronunciation_score: "#2563eb",
                  relax_score: "#7c3aed",
                  mix_voice_score: "#f97316"
                }
              end

    palette.fetch(key.to_sym, "#475569")
  end

  def singing_specific_growth_summary_message(diagnosis, key, kind)
    case diagnosis.performance_type.to_s
    when "guitar"
      specific_growth_summary_for_guitar(key, kind)
    when "bass"
      specific_growth_summary_for_bass(key, kind)
    when "drums"
      specific_growth_summary_for_drums(key, kind)
    when "keyboard"
      specific_growth_summary_for_keyboard(key, kind)
    when "band"
      specific_growth_summary_for_band(key, kind)
    else
      specific_growth_summary_for_vocal(key, kind)
    end
  end

  def specific_growth_summary_for_vocal(key, kind)
    case [key.to_sym, kind]
    when [:volume_score, :growth] then "声量が伸びています。声の前への出方が少しずつ安定してきています。"
    when [:pronunciation_score, :growth] then "発音が伸びています。言葉の伝わり方が安定してきています。"
    when [:relax_score, :growth] then "リラックスが伸びています。力みが減って声の通りが自然になってきています。"
    when [:mix_voice_score, :growth] then "ミックスボイスが伸びています。高音へのつながりが少しずつ整ってきています。"
    when [:volume_score, :strength] then "声量が今の強みです。フレーズの存在感を作りやすい状態です。"
    when [:pronunciation_score, :strength] then "発音が今の強みです。言葉を届ける力があります。"
    when [:relax_score, :strength] then "リラックスが今の強みです。無理の少ない響きを作りやすいです。"
    when [:mix_voice_score, :strength] then "ミックスボイスが今の強みです。音域のつながりに良さがあります。"
    when [:volume_score, :focus] then "声量を次に整えると、サビや要所の伝わり方がさらに良くなります。"
    when [:pronunciation_score, :focus] then "発音を次に整えると、言葉の輪郭がさらに伝わりやすくなります。"
    when [:relax_score, :focus] then "リラックスを次に整えると、声の通りと安定感がさらに良くなります。"
    else "ミックスボイスを次に整えると、高音のつながりがさらに自然になりやすいです。"
    end
  end

  def specific_growth_summary_for_guitar(key, kind)
    case [key.to_sym, kind]
    when [:attack_score, :growth] then "アタックが伸びています。音の輪郭が安定してきています。"
    when [:muting_score, :growth] then "ミュートが伸びています。余計な響きの整理が少しずつ整ってきています。"
    when [:stability_score, :growth] then "安定感が伸びています。フレーズ全体のまとまりが出やすくなっています。"
    when [:attack_score, :strength] then "アタックが今の強みです。発音の立ち上がりが前に出やすい状態です。"
    when [:muting_score, :strength] then "ミュートが今の強みです。鳴らしたい音を整理しやすい状態です。"
    when [:stability_score, :strength] then "安定感が今の強みです。演奏の芯を保ちやすいです。"
    when [:attack_score, :focus] then "アタックを次に伸ばすと、音の抜け方と輪郭がさらに映えやすくなります。"
    when [:muting_score, :focus] then "ミュートを次に整えると、演奏全体の洗練度がさらに上がりやすいです。"
    else "安定感を次に整えると、演奏の完成度がぐっと上がりやすいです。"
    end
  end

  def specific_growth_summary_for_bass(key, kind)
    case [key.to_sym, kind]
    when [:groove_score, :growth] then "グルーヴが伸びています。土台感が少しずつ整ってきています。"
    when [:note_length_score, :growth] then "音価が伸びています。音の長さの揃いが自然になってきています。"
    when [:stability_score, :growth] then "安定感が伸びています。低音の支え方が安定してきています。"
    when [:groove_score, :strength] then "グルーヴが今の強みです。曲全体を前に進める力があります。"
    when [:note_length_score, :strength] then "音価が今の強みです。フレーズの説得力を作りやすいです。"
    when [:stability_score, :strength] then "安定感が今の強みです。低音の土台を保ちやすいです。"
    when [:groove_score, :focus] then "グルーヴを次に伸ばすと、ベースライン全体の推進力がさらに強くなります。"
    when [:note_length_score, :focus] then "音価を次に整えると、ノリと説得力がさらに増しやすいです。"
    else "安定感を次に整えると、低音の支え方がさらに強くなりやすいです。"
    end
  end

  def specific_growth_summary_for_drums(key, kind)
    case [key.to_sym, kind]
    when [:tempo_stability_score, :growth] then "テンポ安定が伸びています。演奏全体の支えが強くなっています。"
    when [:rhythm_precision_score, :growth] then "リズム精度が伸びています。ビートの芯が見えやすくなっています。"
    when [:dynamics_score, :growth] then "ダイナミクスが伸びています。演奏の立体感が少しずつ出てきています。"
    when [:fill_control_score, :growth] then "フィルが伸びています。流れの戻し方が自然になってきています。"
    when [:tempo_stability_score, :strength] then "テンポ安定が今の強みです。ビートの土台を安心して支えやすいです。"
    when [:rhythm_precision_score, :strength] then "リズム精度が今の強みです。叩きの芯を作りやすい状態です。"
    when [:dynamics_score, :strength] then "ダイナミクスが今の強みです。強弱で演奏に立体感を出しやすいです。"
    when [:fill_control_score, :strength] then "フィルが今の強みです。展開の流れを自然につなぎやすいです。"
    when [:tempo_stability_score, :focus] then "テンポ安定を次に整えると、演奏全体の安心感がさらに増しやすいです。"
    when [:rhythm_precision_score, :focus] then "リズム精度を次に整えると、ビートの説得力がさらに強くなりやすいです。"
    when [:dynamics_score, :focus] then "ダイナミクスを次に伸ばすと、演奏の立体感がさらに出しやすくなります。"
    else "フィルの流れを次に整えると、展開のまとまりがさらに良くなりやすいです。"
    end
  end

  def specific_growth_summary_for_keyboard(key, kind)
    case [key.to_sym, kind]
    when [:chord_stability_score, :growth] then "コード安定が伸びています。和音のまとまりが少しずつ整ってきています。"
    when [:note_connection_score, :growth] then "音のつながりが伸びています。フレーズが自然につながりやすくなっています。"
    when [:touch_score, :growth] then "タッチが伸びています。音の粒が整ってきています。"
    when [:harmony_score, :growth] then "ハーモニーが伸びています。響きの支え方が自然になってきています。"
    when [:chord_stability_score, :strength] then "コード安定が今の強みです。和音の支え方に安心感があります。"
    when [:note_connection_score, :strength] then "音のつながりが今の強みです。フレーズの流れを作りやすいです。"
    when [:touch_score, :strength] then "タッチが今の強みです。打鍵の丁寧さが伝わりやすい状態です。"
    when [:harmony_score, :strength] then "ハーモニーが今の強みです。伴奏としてのまとまりがあります。"
    when [:chord_stability_score, :focus] then "コード安定を次に整えると、伴奏全体の安心感がさらに増しやすいです。"
    when [:note_connection_score, :focus] then "音のつながりを次に整えると、演奏全体がさらに自然に聴こえやすくなります。"
    when [:touch_score, :focus] then "タッチを次に伸ばすと、上品さと粒立ちがさらに出しやすくなります。"
    else "ハーモニーを次に整えると、響きのまとまりがさらに良くなりやすいです。"
    end
  end

  def specific_growth_summary_for_band(key, kind)
    case [key.to_sym, kind]
    when [:ensemble_score, :growth] then "アンサンブル力が伸びています。各パートの噛み合いが少しずつ整ってきています。"
    when [:volume_balance_score, :growth] then "音量バランスが伸びています。出過ぎる音と埋もれる音の整理が進んでいます。"
    when [:groove_score, :growth] then "グルーヴが伸びています。バンド全体のノリがまとまりやすくなっています。"
    when [:dynamics_score, :growth] then "ダイナミクスが伸びています。展開の強弱差が伝わりやすくなっています。"
    when [:cohesion_score, :growth] then "全体のまとまりが伸びています。バンドとしてひとつに聴こえやすくなっています。"
    when [:ensemble_score, :strength] then "アンサンブル力が今の強みです。各パートの噛み合いに良さがあります。"
    when [:volume_balance_score, :strength] then "音量バランスが今の強みです。聴きやすいバンドサウンドを作りやすいです。"
    when [:groove_score, :strength] then "グルーヴが今の強みです。バンド全体を前に進める力があります。"
    when [:dynamics_score, :strength] then "ダイナミクスが今の強みです。曲の展開を立体的に見せやすいです。"
    when [:cohesion_score, :strength] then "全体のまとまりが今の強みです。バンドとしての一体感があります。"
    when [:role_understanding_score, :focus] then "役割理解を次に整えると、各パートの住み分けがさらに明確になりやすいです。"
    when [:volume_balance_score, :focus] then "音量バランスを次に整えると、聴きやすさがさらに上がりやすいです。"
    when [:groove_score, :focus] then "グルーヴを次に整えると、バンド全体の推進力がさらに強くなりやすいです。"
    when [:dynamics_score, :focus] then "ダイナミクスを次に伸ばすと、展開の立体感がさらに出しやすくなります。"
    else "アンサンブル力と全体のまとまりを次に整えると、バンドとしての説得力がさらに増しやすいです。"
    end
  end

  def singing_premium_voice_type_scores(diagnosis)
    pitch = diagnosis.pitch_score.to_i
    rhythm = diagnosis.rhythm_score.to_i
    expression = diagnosis.expression_score.to_i
    overall = diagnosis.overall_score.to_i
    volume = premium_average_score(overall, expression)
    relax = premium_average_score(pitch, rhythm)
    pronunciation = premium_average_score(pitch, rhythm, expression)
    closure = premium_average_score(overall, expression)
    tension = premium_average_score(pitch, overall)

    {
      powerful: premium_average_score(volume, overall, expression),
      high_tone: premium_average_score(pitch, tension, overall),
      crystal: premium_average_score(pitch, relax, pronunciation),
      wild: premium_average_score(closure, volume, expression),
      artistic: premium_average_score(expression, rhythm, pronunciation),
      charisma: premium_average_score(expression, overall, rhythm)
    }
  end

  def singing_premium_voice_type_short_description(type_key)
    {
      powerful: "声量・響きの存在感",
      high_tone: "高音の伸びと明るさ",
      crystal: "透明感とやわらかさ",
      wild: "芯・エッジ・迫力",
      artistic: "個性と表現の色",
      charisma: "世界観と引き込み"
    }.fetch(type_key)
  end

  def singing_score_delta_label(delta)
    normalized_delta = singing_normalize_delta(delta)
    return "-" if normalized_delta.nil?
    return "+#{normalized_delta}" if normalized_delta.positive?
    return "±0" if normalized_delta.zero?

    normalized_delta.to_s
  end

  def singing_score_delta_state(delta)
    normalized_delta = singing_normalize_delta(delta)
    return "missing" if normalized_delta.nil?
    return "up" if normalized_delta.positive?
    return "flat" if normalized_delta.zero?

    "down"
  end

  def singing_score_delta_message(delta)
    normalized_delta = singing_normalize_delta(delta)
    return "比較に必要なスコアがまだそろっていません。" if normalized_delta.nil?
    return "前回より伸びが見えています。この感覚を次の練習でも試してみましょう。" if normalized_delta.positive?
    return "前回と近い状態です。安定している部分と変えたい部分を分けて見ていきましょう。" if normalized_delta.zero?

    "今回は違いが出ています。録音環境や曲の難しさも含めて、次の練習のヒントにしましょう。"
  end

  def singing_specific_score_comment(score)
    value = singing_normalize_score(score)
    return "今回の録音だけでは十分な判断ができなかったため、次回も同じ条件で録音すると比較しやすくなります。" if value.nil?
    return "強みとして活かしやすい状態です。" if value >= 80
    return "土台が見えています。少し整えると伸ばしやすい項目です。" if value >= 60

    "次の練習で意識すると変化を作りやすい項目です。"
  end

  def singing_specific_score_delta_message(delta)
    normalized_delta = singing_normalize_delta(delta)
    return "比較に必要な補足スコアがまだそろっていません。" if normalized_delta.nil?
    return "前回より伸びが見えています。今の感覚を次の録音でも試してみましょう。" if normalized_delta.positive?
    return "前回と近い状態です。安定しているポイントとして見ていきましょう。" if normalized_delta.zero?

    "今回は違いが出ています。録音条件や曲の難しさも含めて、振り返りの目安にしましょう。"
  end

  def pitch_practice_menu
    {
      title: "ロングトーン安定練習",
      target: "音程の安定",
      description: "出しやすい高さで同じ音をまっすぐ伸ばし、揺れを少なくする感覚をつかみます。"
    }
  end

  def rhythm_practice_menu
    {
      title: "メトロノーム入り練習",
      target: "リズムの入り",
      description: "短いフレーズをメトロノームに合わせ、歌い始めと語尾のタイミングをそろえていきます。"
    }
  end

  def expression_practice_menu
    {
      title: "サビ前後の強弱練習",
      target: "抑揚と表現",
      description: "小さめの声から自然に広げる練習で、今の良さを保ちながら表現の幅を試します。"
    }
  end

  def strength_practice_menu
    {
      title: "得意フレーズ磨き",
      target: "強みの定着",
      description: "安定して歌えた部分をもう一度録音し、声の出し方や響きを再現しやすくします。"
    }
  end

  def singing_guitar_practice_menus(diagnosis)
    menus = []

    menus << guitar_attack_practice_menu if singing_specific_scores(diagnosis)[:attack_score].to_i < 70
    menus << guitar_muting_practice_menu if singing_specific_scores(diagnosis)[:muting_score].to_i < 70
    menus << guitar_stability_practice_menu if singing_specific_scores(diagnosis)[:stability_score].to_i < 70
    menus << guitar_rhythm_practice_menu if diagnosis.rhythm_score.to_i < 70

    if menus.empty?
      menus << guitar_stability_practice_menu
      menus << guitar_attack_practice_menu
    end

    menus.first(3)
  end

  def guitar_attack_practice_menu
    {
      title: "ピッキングの立ち上がり確認",
      target: "アタック",
      description: "短いフレーズをゆっくり弾き、音の出だしがそろっているかを録音で確認します。"
    }
  end

  def guitar_muting_practice_menu
    {
      title: "不要弦ミュート練習",
      target: "ミュート",
      description: "鳴らしたい音だけが残るように、右手と左手の触れ方を短いパターンで確認します。"
    }
  end

  def guitar_stability_practice_menu
    {
      title: "同じフレーズの反復録音",
      target: "安定感",
      description: "同じフレーズを数回録音し、音量やタイミングのばらつきが少ない弾き方を探します。"
    }
  end

  def guitar_rhythm_practice_menu
    {
      title: "クリック合わせ練習",
      target: "リズム",
      description: "メトロノームに合わせて、ピッキングの位置と音の長さを一定に保つ練習をします。"
    }
  end
end
