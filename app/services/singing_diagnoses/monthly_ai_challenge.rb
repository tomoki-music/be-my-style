module SingingDiagnoses
  class MonthlyAiChallenge
    DURATION_LABEL = "7日間".freeze

    CHALLENGES = {
      "pitch" => {
        title: "音程安定チャレンジ",
        description: "今月は音程の安定感を高めることを目標にしましょう。",
        practice_steps: [
          "基準音をピアノアプリなどで確認する",
          "短い1フレーズだけをゆっくり歌う",
          "録音して、音が上ずる/下がる箇所を確認する"
        ],
        target_label: "音程",
        difficulty: "初級"
      },
      "rhythm" => {
        title: "リズム安定チャレンジ",
        description: "今月はリズムの安定感を高めることを目標にしましょう。",
        practice_steps: [
          "メトロノームを60〜80BPMに設定する",
          "手拍子をしながらAメロだけ歌う",
          "録音して、走る/遅れる箇所を確認する"
        ],
        target_label: "リズム",
        difficulty: "初級"
      },
      "expression" => {
        title: "表現力アップチャレンジ",
        description: "今月は歌詞やフレーズの表情を広げることを目標にしましょう。",
        practice_steps: [
          "歌詞を1行ずつ朗読する",
          "強く歌う場所と優しく歌う場所を決める",
          "同じフレーズを表情を変えて3パターン録音する"
        ],
        target_label: "表現",
        difficulty: "中級"
      }
    }.freeze

    FALLBACK_CHALLENGE = {
      title: "まずは診断を積み上げよう",
      description: "今月と前月にそれぞれ診断を行うと、あなた専用のチャレンジがより正確になります。",
      practice_steps: [
        "今月中にもう1回診断してみる",
        "同じ曲で診断して変化を比べる",
        "診断結果のおすすめ練習メニューを1つ試す"
      ],
      target_label: "診断習慣",
      target_key: "habit",
      difficulty: "入門",
      source: "fallback"
    }.freeze

    def initialize(customer, growth_report: nil)
      @customer = customer
      @growth_report = growth_report
    end

    def call
      report = growth_report || MonthlyGrowthReport.new(customer).call
      return build_fallback unless report[:has_enough_data]

      focus_key = report[:focus_key].to_s
      challenge = CHALLENGES[focus_key]
      return build_fallback if challenge.blank?

      build_challenge(challenge, focus_key)
    end

    private

    attr_reader :customer, :growth_report

    def build_challenge(challenge, focus_key)
      challenge.merge(
        target_key: focus_key,
        duration_label: DURATION_LABEL,
        source: "monthly_growth_report",
        available: true
      )
    end

    def build_fallback
      FALLBACK_CHALLENGE.merge(
        duration_label: DURATION_LABEL,
        available: true
      )
    end
  end
end
