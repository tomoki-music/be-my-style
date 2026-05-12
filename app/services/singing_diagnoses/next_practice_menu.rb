module SingingDiagnoses
  class NextPracticeMenu
    LOW_SCORE_THRESHOLD = 75
    HIGH_OVERALL_THRESHOLD = 85
    MAX_ITEMS = 3

    MENU_DEFINITIONS = [
      {
        score_key: :pitch_score,
        threshold: LOW_SCORE_THRESHOLD,
        title: "音程安定トレーニング",
        description: "まずは短いフレーズをゆっくり歌い、録音を聴きながら音程のズレを確認しましょう。",
        reason: "今回の診断では pitch_score がやや低めでした。",
        level: "初級",
        icon: "🎯"
      },
      {
        score_key: :rhythm_score,
        threshold: LOW_SCORE_THRESHOLD,
        title: "リズムキープ練習",
        description: "メトロノームに合わせて手拍子と歌を分けて練習し、拍の中心を感じる時間を作りましょう。",
        reason: "今回の診断では rhythm_score がやや低めでした。",
        level: "初級",
        icon: "🥁"
      },
      {
        score_key: :expression_score,
        threshold: LOW_SCORE_THRESHOLD,
        title: "表現力アップ練習",
        description: "歌詞の中で一番届けたい言葉を決め、声量や息の量を少しずつ変えて歌ってみましょう。",
        reason: "今回の診断では expression_score がやや低めでした。",
        level: "中級",
        icon: "✨"
      }
    ].freeze

    HIGH_OVERALL_MENU = {
      title: "次のステージ：楽曲表現チャレンジ",
      description: "今の安定感を活かして、Aメロ・サビ・ラストで表情を変えるなど、1曲全体の物語づくりに挑戦しましょう。",
      reason: "今回の診断では overall_score が高く、次の表現テーマに進める状態です。",
      level: "上級",
      icon: "🚀"
    }.freeze

    FALLBACK_MENU = {
      title: "基礎バランス確認メニュー",
      description: "音程・リズム・表現を1つずつ短く確認し、次回の診断で変化を見つけやすい状態を作りましょう。",
      reason: "今回の診断結果をもとに、全体のバランスを整える練習がおすすめです。",
      level: "初級",
      icon: "🌱"
    }.freeze

    def initialize(diagnosis)
      @diagnosis = diagnosis
    end

    def call
      menus = low_score_menus
      menus << HIGH_OVERALL_MENU if score(:overall_score) >= HIGH_OVERALL_THRESHOLD
      menus << FALLBACK_MENU if menus.empty?
      menus.first(MAX_ITEMS)
    end

    private

    attr_reader :diagnosis

    def low_score_menus
      MENU_DEFINITIONS.filter_map do |menu|
        value = score(menu[:score_key])
        menu.except(:score_key, :threshold) if value.positive? && value < menu[:threshold]
      end
    end

    def score(key)
      diagnosis.public_send(key).to_i
    end
  end
end
