require "axlsx"

module Events
  # イベントの「演奏リスト」(.xlsx)。当日の進行表・共有資料として配る想定のため、
  # 会員情報は表示名(Customer#name / EventBandMember#label)だけを載せる。
  #
  # 曲順・募集判定・バンド出演曲の扱いはイベント詳細の楽曲表に合わせる:
  # - 曲順は Event#songs(position順)
  # - パート列への振り分けは PartNameNormalizer(詳細画面の normalized_join_parts_for_column と同じ)
  # - 現役参加者0人のパートは「募集中」(Song#recruiting_join_parts と同じ基準)、
  #   その曲に無いパートは「—」(募集対象外)
  # - バンド出演曲は固定メンバーだけを載せ、担当者のいないパートも「—」(一般募集はしない)
  #
  # 写真・音源の共有フォルダURLと曲ごとの演奏動画URLは対応するデータが無いため、手入力用の空欄にする
  # (Event#url は「参考URL」、Song#youtube_url は参考動画で、意味が違うので転用しない)。
  class PerformanceListXlsx
    SHEET_NAME = "演奏リスト".freeze
    MIME_TYPE = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet".freeze

    RECRUITING = "募集中".freeze
    NOT_RECRUITED = "—".freeze

    PART_COLUMNS = [
      ["Vocal", "Vo"],
      ["Guitar", "Gt"],
      ["Bass", "Ba"],
      ["Drums", "Dr"],
      ["Keyboard", "Key"]
    ].freeze
    OTHER_PART = "Other".freeze

    HEADER_ROW = 6
    WEEKDAYS = %w[日 月 火 水 木 金 土].freeze

    COLOR_TEXT = "1F1F1F".freeze
    COLOR_HEADER_FILL = "DCE6F2".freeze
    COLOR_STRIPE_FILL = "EFEFEF".freeze
    COLOR_INPUT_FILL = "FFF8E1".freeze
    COLOR_BORDER = "9E9E9E".freeze
    COLOR_RECRUITING = "C62828".freeze
    COLOR_MUTED = "9E9E9E".freeze

    def self.call(event)
      new(event).to_stream
    end

    def initialize(event)
      @event = event
      @songs = event.songs.to_a
    end

    def filename
      "#{@event.event_name.to_s.gsub(%r{[\\/:*?"<>|\r\n]}, '_').strip}_演奏リスト.xlsx"
    end

    def to_stream
      package = Axlsx::Package.new
      package.use_shared_strings = true
      build_sheet(package.workbook)
      package.to_stream.read
    end

    # [列見出し, パート列キー] の並び。キーは JoinPart::NAME_OPTIONS の値か、
    # 正規化できない旧パート名(そのまま追加列にする)。
    def part_columns
      @part_columns ||= begin
        fixed = PART_COLUMNS.map { |key, label| [label, key] }
        extras = extra_part_names.map { |name| [name, name] }
        fixed + extras + [[OTHER_PART, OTHER_PART]]
      end
    end

    def headers
      ["No.", "演奏時間", "演奏曲目", *part_columns.map(&:first), "演奏動画URL"]
    end

    def rows
      @songs.each_with_index.map do |song, index|
        [
          (index + 1).to_s,
          song.performance_start_time.to_s,
          song_title(song),
          *part_columns.map { |_label, key| part_cell(song, key) },
          ""
        ]
      end
    end

    private

    # 「Cho」「Percussion」など、意味を一意に決められず固定列に寄せないパート名。
    # 参加者を落とさないよう、詳細画面には無い追加列として出す。
    def extra_part_names
      @songs.reject(&:band_performance?).flat_map do |song|
        song.join_parts.filter_map do |join_part|
          next if column_key_for(join_part)

          join_part.join_part_name.to_s.strip.presence
        end
      end.uniq
    end

    def column_key_for(join_part)
      PerformanceHistory::PartNameNormalizer.normalize(join_part.join_part_name)
    end

    def join_parts_for(song, key)
      song.join_parts.select do |join_part|
        (column_key_for(join_part) || join_part.join_part_name.to_s.strip) == key
      end
    end

    def part_cell(song, key)
      return band_part_cell(song, key) if song.band_performance?

      join_parts = join_parts_for(song, key)
      return NOT_RECRUITED if join_parts.empty?

      # 同じ列に複数パート(例: Guitar1/Guitar2)がある場合は、空き枠も1件ずつ「募集中」と並べる。
      join_parts.flat_map do |join_part|
        names = join_part.customers.reject(&:is_deleted).map(&:name)
        names.presence || [RECRUITING]
      end.uniq.join("\n")
    end

    def band_part_cell(song, key)
      member = song.event_band.member_for(key)
      member&.label.presence || NOT_RECRUITED
    end

    def song_title(song)
      title = [song.song_name, song.artist_name.presence].compact.join(" / ")
      return title unless song.band_performance?

      "#{title}\n🎸 バンド出演：#{song.event_band.name}"
    end

    def event_date_label
      start_time = @event.event_start_time
      end_time = @event.event_end_time
      date = "#{start_time.year}年#{start_time.month}月#{start_time.day}日(#{WEEKDAYS[start_time.wday]})"
      time = "#{start_time.strftime('%H:%M')}〜#{end_time&.strftime('%H:%M')}"
      "開催日：#{date} #{time}　会場：#{@event.place}"
    end

    def build_sheet(workbook)
      styles = build_styles(workbook.styles)
      column_count = headers.size
      last_column = Axlsx.col_ref(column_count - 1)
      url_column_index = column_count - 1

      workbook.add_worksheet(name: SHEET_NAME) do |sheet|
        sheet.escape_formulas = true

        sheet.add_row(["#{@event.event_name}【演奏リスト】"], style: styles[:title], types: [:string], height: 36)
        sheet.add_row([event_date_label], style: styles[:date], types: [:string], height: 22)
        sheet.add_row(["写真・音源の共有フォルダURL（写真や音源ファイルはこちらにアップロードしてください）"],
                      style: styles[:share_label], types: [:string], height: 22)
        sheet.add_row([""] * column_count, style: styles[:input], types: [:string] * column_count, height: 26)
        sheet.add_row(["※ 会員はアプリ内の表示名で記載しています。「募集中」は参加者募集中のパート、「—」は募集対象外のパートです。"],
                      style: styles[:note], types: [:string], height: 18)
        sheet.add_row(headers, style: styles[:header], types: [:string] * column_count, height: 24)

        rows.each_with_index do |values, index|
          stripe = index.odd? ? :stripe : :plain
          cell_styles = values.each_with_index.map do |value, column_index|
            body_style(styles, stripe, value, column_index, url_column_index)
          end
          sheet.add_row(values, style: cell_styles, types: [:string] * column_count, height: row_height(values))
        end

        %w[A1 A2 A3 A4 A5].each { |cell| sheet.merge_cells("#{cell}:#{last_column}#{cell[1..]}") }
        sheet.column_widths(*column_widths)
        sheet.sheet_view.pane do |pane|
          pane.top_left_cell = "A#{HEADER_ROW + 1}"
          pane.state = :frozen
          pane.y_split = HEADER_ROW
        end
        sheet.page_setup.set(orientation: :landscape, paper_size: 9, fit_to_width: 1, fit_to_height: 0)
        sheet.print_options.horizontal_centered = true
        sheet.page_margins.set(left: 0.4, right: 0.4, top: 0.5, bottom: 0.5)
        workbook.add_defined_name("'#{SHEET_NAME}'!$#{HEADER_ROW}:$#{HEADER_ROW}",
                                  local_sheet_id: sheet.index, name: "_xlnm.Print_Titles")
      end
    end

    def body_style(styles, stripe, value, column_index, url_column_index)
      kind =
        if column_index <= 1 then :center
        elsif column_index == 2 then :song
        elsif column_index == url_column_index then :text
        elsif value == RECRUITING then :recruiting
        elsif value == NOT_RECRUITED then :not_recruited
        else :member
        end
      styles[:"#{stripe}_#{kind}"]
    end

    def column_widths
      [6, 10, 34, *part_columns.map { 15 }, 32]
    end

    # 折り返し表示の行数に合わせて行の高さを決める(xlsxは開いた側で自動調整されないことがあるため)。
    def row_height(values)
      widths = column_widths
      lines = values.each_with_index.map do |value, index|
        capacity = [widths[index] - 2, 1].max
        value.to_s.split("\n").sum do |line|
          display_width = line.each_char.sum { |char| char.ascii_only? ? 1 : 2 }
          [(display_width.to_f / capacity).ceil, 1].max
        end
      end.max
      [lines, 1].max * 18 + 8
    end

    def build_styles(stylesheet)
      border = { style: :thin, color: COLOR_BORDER }
      base = { font_name: "Arial", fg_color: COLOR_TEXT, sz: 11 }
      wrap_left = { horizontal: :left, vertical: :center, wrap_text: true }
      wrap_center = { horizontal: :center, vertical: :center, wrap_text: true }

      styles = {
        title: stylesheet.add_style(base.merge(b: true, sz: 22, alignment: { vertical: :center })),
        date: stylesheet.add_style(base.merge(sz: 12, alignment: { vertical: :center })),
        share_label: stylesheet.add_style(base.merge(b: true, sz: 12, alignment: { vertical: :center })),
        input: stylesheet.add_style(base.merge(sz: 12, bg_color: COLOR_INPUT_FILL, border: border,
                                               alignment: { vertical: :center })),
        note: stylesheet.add_style(base.merge(sz: 9, fg_color: "616161", alignment: { vertical: :center })),
        header: stylesheet.add_style(base.merge(b: true, bg_color: COLOR_HEADER_FILL, border: border, alignment: wrap_center))
      }

      { plain: "FFFFFF", stripe: COLOR_STRIPE_FILL }.each do |stripe, fill|
        row_base = base.merge(bg_color: fill, border: border)
        styles[:"#{stripe}_center"] = stylesheet.add_style(row_base.merge(alignment: wrap_center))
        styles[:"#{stripe}_song"] = stylesheet.add_style(row_base.merge(b: true, alignment: wrap_left))
        styles[:"#{stripe}_text"] = stylesheet.add_style(row_base.merge(alignment: wrap_left))
        styles[:"#{stripe}_member"] = stylesheet.add_style(row_base.merge(alignment: wrap_center))
        styles[:"#{stripe}_recruiting"] = stylesheet.add_style(row_base.merge(b: true, fg_color: COLOR_RECRUITING,
                                                                              alignment: wrap_center))
        styles[:"#{stripe}_not_recruited"] = stylesheet.add_style(row_base.merge(fg_color: COLOR_MUTED, alignment: wrap_center))
      end
      styles
    end
  end
end
