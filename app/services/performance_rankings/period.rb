module PerformanceRankings
  # 演奏実績ランキングの集計期間を表す値オブジェクト。
  #
  # ■ 基準
  #   イベント開催日(events.event_start_time)を Asia/Tokyo で解釈する。
  #   config.time_zone = "Tokyo" のため Time.zone.local / Time.zone.today がそのまま日本時間。
  #
  # ■ 返す範囲
  #   #range は [from, to) の半開区間(from 以上 to 未満)。SQL 側でも
  #   event_start_time >= from AND event_start_time < to と半開で比較するため、
  #   月末 23:59 と翌月 0:00 の二重計上や取りこぼしが起きない。
  #   「全期間」は nil(期間で絞り込まない)。
  #
  # ■ 不正値
  #   preset が未知・日付がパースできない・存在しない日付 → 全期間(all)へ倒す。例外は投げない。
  #   カスタム期間で開始日 > 終了日 → #invalid? が true。呼び出し側はエラー表示に使う
  #   (集計は空になる)。
  PRESETS = %w[this_month last_month this_year past_year all custom].freeze
  DEFAULT_PRESET = "all".freeze

  class Period
    attr_reader :preset

    def initialize(preset: nil, start_on: nil, end_on: nil, today: nil)
      @today = today || Time.zone.today
      @preset = PRESETS.include?(preset.to_s) ? preset.to_s : DEFAULT_PRESET
      @raw_start_on = start_on
      @raw_end_on = end_on
    end

    # フォームの日付入力欄の復元用。パースできない値は nil。
    def start_on
      @start_on ||= parse_date(@raw_start_on)
    end

    def end_on
      @end_on ||= parse_date(@raw_end_on)
    end

    # カスタム期間で開始日が終了日より後。集計は行わずエラーを表示する。
    def invalid?
      preset == "custom" && start_on.present? && end_on.present? && start_on > end_on
    end

    # [from, to) の半開区間。全期間・不正なカスタム期間は nil。
    def range
      return nil if invalid?

      case preset
      when "this_month"
        from = @today.beginning_of_month
        [time(from), time(from.next_month)]
      when "last_month"
        from = @today.beginning_of_month.prev_month
        [time(from), time(from.next_month)]
      when "this_year"
        from = @today.beginning_of_year
        [time(from), time(from.next_year)]
      when "past_year"
        # 「過去1年間」= 今日を含む直近365(366)日。今日の終わり(翌日0:00)を上限にする。
        [time(@today.prev_year.next_day), time(@today.next_day)]
      when "custom"
        return nil if start_on.blank? && end_on.blank?

        from = start_on ? time(start_on) : nil
        to = end_on ? time(end_on.next_day) : nil
        [from, to]
      end
    end

    def from
      range&.first
    end

    def to
      range&.last
    end

    def label
      {
        "this_month" => "今月",
        "last_month" => "先月",
        "this_year" => "今年",
        "past_year" => "過去1年間",
        "all" => "全期間",
        "custom" => "カスタム期間"
      }.fetch(preset)
    end

    def to_params
      params = { period: preset }
      if preset == "custom"
        params[:start_on] = start_on.iso8601 if start_on
        params[:end_on] = end_on.iso8601 if end_on
      end
      params
    end

    private

    def time(date)
      Time.zone.local(date.year, date.month, date.day)
    end

    def parse_date(value)
      return value if value.is_a?(Date)

      string = value.to_s.strip
      return nil if string.blank?

      Date.iso8601(string)
    rescue ArgumentError, TypeError
      begin
        Date.parse(string)
      rescue ArgumentError, TypeError, RangeError
        nil
      end
    end
  end
end
