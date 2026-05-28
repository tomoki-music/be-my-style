module Singing
  # AIコメントテキストから「次回ミッション」を抽出する。
  # 完璧な NLP は不要。「次回は〜」「意識してみましょう」などの
  # シグナル句を手がかりにミッション文を切り出す。
  class NextMissionExtractor
    MISSION_TRIGGER_PATTERNS = [
      /次回は(.+?)(?:[。！\n]|$)/,
      /次回(?:の練習)?(?:では|で)(.+?)(?:[。！\n]|$)/,
      /ぜひ(.+?)(?:意識|チャレンジ|試し)てみ(?:ましょう|てください)(?:[。！\n]|$)/,
      /(.+?)(?:意識してみましょう|チャレンジしてみましょう|試してみましょう)/,
      /(.+?)を意識(?:して|し)(?:みましょう|ながら歌って)/,
    ].freeze

    TITLE_MAX = 30
    BODY_MAX  = 120

    def self.call(ai_comment)
      new(ai_comment).call
    end

    def initialize(ai_comment)
      @ai_comment = ai_comment.to_s.strip
    end

    def call
      return nil if @ai_comment.blank?

      sentence = extract_mission_sentence
      return nil if sentence.blank?

      {
        title: build_title(sentence),
        body:  sentence.truncate(BODY_MAX)
      }
    end

    private

    def extract_mission_sentence
      MISSION_TRIGGER_PATTERNS.each do |pattern|
        match = @ai_comment.match(pattern)
        next unless match

        captured = match[1]&.strip
        full     = match[0]&.strip

        candidate = captured.present? ? full : nil
        next if candidate.blank?
        next if candidate.length < 8

        return candidate
      end

      nil
    end

    def build_title(sentence)
      # 「次回は○○を意識」のような短い動詞句をタイトルに
      short = sentence
        .gsub(/次回(?:は|の練習では|では|で)?/, "")
        .gsub(/(?:意識|チャレンジ|試し)てみ(?:ましょう|てください)/, "を意識")
        .gsub(/[。！]/, "")
        .strip

      short.truncate(TITLE_MAX).presence || sentence.truncate(TITLE_MAX)
    end
  end
end
