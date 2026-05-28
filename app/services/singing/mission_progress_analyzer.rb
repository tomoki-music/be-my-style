module Singing
  # 前回ミッションが今回診断でどれだけ達成されたかを分析する。
  # 厳密な判定は不要。ミッションキーワードとスコア改善の関連を簡易照合する。
  class MissionProgressAnalyzer
    SCORE_KEYWORD_MAP = {
      pitch_score:      %w[音程 ピッチ 音 Key key],
      rhythm_score:     %w[リズム テンポ 拍 グルーヴ タイミング 入り],
      expression_score: %w[表現 ダイナミクス 抑揚 強弱 感情 メリハリ アンサンブル]
    }.freeze

    GROWTH_THRESHOLD = 3

    Result = Struct.new(:success?, :score_key, :delta, :score_label, keyword_init: true)

    def self.call(current_diagnosis, previous_diagnosis)
      new(current_diagnosis, previous_diagnosis).call
    end

    def initialize(current_diagnosis, previous_diagnosis)
      @current    = current_diagnosis
      @previous   = previous_diagnosis
    end

    def call
      return nil if @current.blank? || @previous.blank?
      return nil if @previous.next_mission_title.blank? && @previous.next_mission_body.blank?

      mission_text = [@previous.next_mission_title, @previous.next_mission_body].compact.join(" ")
      matched_key  = match_score_key(mission_text)

      if matched_key
        delta = score_delta(matched_key)
        Result.new(
          success?:    delta.present? && delta >= GROWTH_THRESHOLD,
          score_key:   matched_key,
          delta:       delta,
          score_label: score_label_for(matched_key)
        )
      else
        best = best_growth
        return nil if best.nil?

        Result.new(
          success?:    best[:delta] >= GROWTH_THRESHOLD,
          score_key:   best[:key],
          delta:       best[:delta],
          score_label: best[:label]
        )
      end
    end

    private

    def match_score_key(text)
      SCORE_KEYWORD_MAP.each do |score_key, keywords|
        return score_key if keywords.any? { |kw| text.include?(kw) }
      end
      nil
    end

    def score_delta(score_key)
      current_val  = @current.public_send(score_key)
      previous_val = @previous.public_send(score_key)
      return nil if current_val.nil? || previous_val.nil?

      current_val - previous_val
    end

    def best_growth
      SingingDiagnosis::SCORE_ATTRIBUTES
        .filter_map do |attr|
          delta = score_delta(attr)
          next unless delta&.positive?

          { key: attr, delta: delta, label: score_label_for(attr) }
        end
        .max_by { |item| item[:delta] }
    end

    def score_label_for(score_key)
      {
        overall_score:    "総合",
        pitch_score:      "音程",
        rhythm_score:     "リズム",
        expression_score: "表現"
      }.fetch(score_key, score_key.to_s)
    end
  end
end
