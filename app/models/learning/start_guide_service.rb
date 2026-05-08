module Learning
  class StartGuideService
    Step = Struct.new(:day, :title, :body, :completed, :current, keyword_init: true)
    Guide = Struct.new(:steps, :completed_days, :remaining_days, :current_step, :progress_percent, keyword_init: true) do
      def completed?
        remaining_days.zero?
      end
    end
    Feedback = Struct.new(:headline, :change, :next_action, keyword_init: true)
    Badge = Struct.new(:key, :label, :earned, keyword_init: true) do
      def earned?
        earned
      end
    end

    STEP_DEFINITIONS = [
      ["ログイン＋1つ完了", "まず1つ記録して、続ける入口を作ろう"],
      ["もう1つ挑戦", "昨日より少しだけ前に進もう"],
      ["3日継続達成", "続けるリズムができ始めています"],
      ["少し難しい練習", "基礎に慣れたら一段上に挑戦しよう"],
      ["振り返り", "できたことを見て、次の練習を決めよう"],
      ["改善チャレンジ", "苦手を1つ選んで短く練習しよう"],
      ["1週間達成", "1週間続いた実感を次の週につなげよう"]
    ].freeze

    PART_NEXT_ACTIONS = {
      "vocal" => "次はリズム練習を強化すると、歌い出しがさらに安定します",
      "guitar" => "次はコードチェンジを短く反復すると、演奏が止まりにくくなります",
      "bass" => "次はリズムキープを意識すると、バンド全体がまとまりやすくなります",
      "drums" => "次はテンポを一定に保つ練習で、合奏がさらに安定します",
      "keyboard" => "次はコードを一定の拍で弾く練習を足すと、伴奏が安定します",
      "band" => "次は入りと終わりを合わせる練習で、合奏の精度が上がります"
    }.freeze

    def initialize(student)
      @student = student
    end

    def guide
      completed_days = [practiced_days.count, 7].min
      current_index = completed_days >= 7 ? 6 : completed_days

      steps = STEP_DEFINITIONS.each_with_index.map do |(title, body), index|
        Step.new(
          day: index + 1,
          title: title,
          body: body,
          completed: index < completed_days,
          current: index == current_index
        )
      end

      Guide.new(
        steps: steps,
        completed_days: completed_days,
        remaining_days: 7 - completed_days,
        current_step: steps[current_index],
        progress_percent: ((completed_days.to_f / 7) * 100).round
      )
    end

    def feedback
      Feedback.new(
        headline: headline,
        change: change_message,
        next_action: PART_NEXT_ACTIONS.fetch(@student.main_part.to_s, PART_NEXT_ACTIONS["band"])
      )
    end

    def badges
      completed_days = practiced_days.count
      [
        Badge.new(key: :first_completion, label: "初完了", earned: completed_days >= 1),
        Badge.new(key: :three_day_streak, label: "3日継続", earned: completed_days >= 3),
        Badge.new(key: :week_complete, label: "1週間達成", earned: completed_days >= 7)
      ]
    end

    def yesterday_summary
      log = progress_logs.find { |item| item.practiced_on == Date.current - 1 }
      log&.training_title
    end

    private

    def headline
      return "まずは1つやってみよう！" if progress_logs.empty?
      return "いいペース！このまま続けよう" if practiced_days.count >= 3
      return "かなり順調！次のレベルに挑戦" if achievement_rate >= 70

      "少しずつでOK！積み重ねが大事"
    end

    def change_message
      if this_week_log_count > last_week_log_count
        "前回より進捗が増えています"
      elsif this_week_log_count.positive?
        "今週も練習記録を残せています"
      elsif last_log
        "前回から少し間が空いています"
      else
        "最初の記録を作るところから始めましょう"
      end
    end

    def achievement_rate
      trainings = @student.learning_student_trainings.to_a
      return 0 if trainings.empty?

      achieved = trainings.count { |training| training.status == "achieved" || training.star? }
      ((achieved.to_f / trainings.count) * 100).round
    end

    def this_week_log_count
      @this_week_log_count ||= progress_logs.count { |log| Date.current.all_week.cover?(log.practiced_on) }
    end

    def last_week_log_count
      @last_week_log_count ||= progress_logs.count { |log| 1.week.ago.to_date.all_week.cover?(log.practiced_on) }
    end

    def last_log
      @last_log ||= progress_logs.max_by(&:practiced_on)
    end

    def practiced_days
      @practiced_days ||= progress_logs.map(&:practiced_on).uniq.sort
    end

    def progress_logs
      @progress_logs ||= @student.learning_progress_logs.to_a
    end
  end
end
