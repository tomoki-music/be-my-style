module Singing
  class YearlyGrowthReport
    ScoreGrowth = Struct.new(:key, :label, :delta, :first_value, :last_value, keyword_init: true)
    ChallengeSummary = Struct.new(:target_key, :label, :count, keyword_init: true)
    SongSummary = Struct.new(:title, :count, keyword_init: true)
    Report = Struct.new(
      :year,
      :diagnosis_count,
      :top_growth,
      :personal_best_updates_count,
      :top_challenge,
      :top_song,
      :coach_message,
      :emotional_copy,
      keyword_init: true
    ) do
      def present?
        diagnosis_count.to_i.positive?
      end
    end

    SCORE_LABELS = {
      overall_score: "総合力",
      pitch_score: "音程",
      rhythm_score: "リズム",
      expression_score: "表現力"
    }.freeze

    CHALLENGE_LABELS = {
      "habit" => "習慣化",
      "pitch" => "音程",
      "rhythm" => "リズム",
      "expression" => "表現力"
    }.freeze

    def self.call(customer, reference_time: Time.current)
      new(customer, reference_time: reference_time).call
    end

    def initialize(customer, reference_time: Time.current)
      @customer = customer
      @reference_time = reference_time
    end

    def call
      Report.new(
        year: year,
        diagnosis_count: diagnoses.size,
        top_growth: top_growth,
        personal_best_updates_count: personal_best_updates_count,
        top_challenge: top_challenge,
        top_song: top_song,
        coach_message: coach_message,
        emotional_copy: emotional_copy
      )
    end

    private

    attr_reader :customer, :reference_time

    def year
      reference_time.in_time_zone.year
    end

    def year_range
      reference_time.in_time_zone.all_year
    end

    def diagnoses
      @diagnoses ||= customer.singing_diagnoses
        .completed
        .where(created_at: year_range)
        .order(:created_at, :id)
        .to_a
    end

    def challenge_progresses
      @challenge_progresses ||= customer.singing_ai_challenge_progresses
        .where(challenge_month: year_range)
        .where("tried = ? OR completed = ? OR next_diagnosis_planned = ?", true, true, true)
        .to_a
    end

    def top_growth
      growths = SCORE_LABELS.filter_map do |attribute, label|
        values = diagnoses.filter_map { |diagnosis| diagnosis.public_send(attribute) }
        next if values.size < 2

        delta = values.last.to_i - values.first.to_i
        ScoreGrowth.new(
          key: attribute,
          label: label,
          delta: delta,
          first_value: values.first,
          last_value: values.last
        )
      end

      growths.max_by { |growth| [growth.delta.to_i, growth.last_value.to_i] }
    end

    def personal_best_updates_count
      best = nil
      diagnoses.filter_map(&:overall_score).count do |score|
        update = best.nil? || score.to_i > best
        best = [best, score.to_i].compact.max
        update
      end
    end

    def top_challenge
      target_key, grouped = challenge_progresses.group_by(&:target_key).max_by do |key, progresses|
        [progresses.size, CHALLENGE_LABELS.fetch(key, key)]
      end
      return nil if target_key.blank?

      ChallengeSummary.new(
        target_key: target_key,
        label: CHALLENGE_LABELS.fetch(target_key, target_key),
        count: grouped.size
      )
    end

    def top_song
      title, titles = diagnoses
        .map { |diagnosis| diagnosis.song_title.to_s.strip }
        .select(&:present?)
        .group_by(&:itself)
        .max_by { |song_title, grouped_titles| [grouped_titles.size, song_title] }
      return nil if title.blank?

      SongSummary.new(title: title, count: titles.size)
    end

    def coach_message
      return "今年の診断が増えるほど、AIコーチからの振り返りも濃くなっていきます。" if diagnoses.empty?

      if top_growth&.delta.to_i.positive?
        "#{top_growth.label}が#{top_growth.delta}点伸びました。積み重ねた録音は、ちゃんと次の声に変わっています。"
      elsif diagnoses.size >= 3
        "今年は#{diagnoses.size}回、自分の声と向き合いました。数字以上に、続けたこと自体が大きな成長です。"
      else
        "今年の記録が始まりました。次の診断で、変化の輪郭がもっと見えてきます。"
      end
    end

    def emotional_copy
      "#{year}年、あなたは声の現在地を#{diagnoses.size}回たしかめました。小さな録音の積み重ねが、次のステージへの地図になっています。"
    end
  end
end
