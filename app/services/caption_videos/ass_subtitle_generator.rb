module CaptionVideos
  # 編集済みテロップ(VideoCaption)からASS字幕ファイルの中身を生成する。
  # MVPでは1テンプレート固定: 画面下部中央・白文字・黒縁取り・最大2行。
  class AssSubtitleGenerator
    DEFAULT_FONT_FAMILY = "Noto Sans CJK JP".freeze
    MAX_LINES = 2

    def self.call(video_captions, width:, height:)
      new(video_captions, width: width, height: height).call
    end

    def initialize(video_captions, width:, height:)
      @video_captions = video_captions
      @width  = width.to_i.positive?  ? width.to_i  : 1280
      @height = height.to_i.positive? ? height.to_i : 720
    end

    def call
      <<~ASS
        [Script Info]
        ScriptType: v4.00+
        PlayResX: #{@width}
        PlayResY: #{@height}
        WrapStyle: 2
        ScaledBorderAndShadow: yes

        [V4+ Styles]
        Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
        Style: #{style_line}

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        #{dialogue_lines}
      ASS
    end

    private

    def style_line
      [
        "Default",
        font_family,
        font_size,
        "&H00FFFFFF", # PrimaryColour: 白・不透明
        "&H000000FF", # SecondaryColour
        "&H00000000", # OutlineColour: 黒
        "&H00000000", # BackColour
        0, 0, 0, 0,
        100, 100, 0, 0,
        1,             # BorderStyle: 縁取り+影
        outline_width,
        0,             # Shadow
        2,             # Alignment: 下部中央(numpad方式)
        margin_lr, margin_lr, margin_v,
        1
      ].join(",")
    end

    def font_family
      ENV["CAPTION_VIDEO_FONT_FAMILY"].presence || DEFAULT_FONT_FAMILY
    end

    # 解像度に応じてフォントサイズ・縁取り・安全マージンを調整する(縦動画/横動画どちらでも破綻しないように)。
    def font_size
      [(@height * 0.045).round, 16].max
    end

    def outline_width
      [(@height * 0.004).round, 1].max
    end

    def margin_lr
      (@width * 0.05).round
    end

    def margin_v
      (@height * 0.06).round
    end

    def dialogue_lines
      @video_captions.map { |caption| dialogue_line(caption) }.join("\n")
    end

    def dialogue_line(caption)
      start = format_time(caption.start_time.to_f)
      finish = format_time(caption.end_time.to_f)
      "Dialogue: 0,#{start},#{finish},Default,,0,0,0,,#{escape_text(caption.text)}"
    end

    # { } と \ はASSのオーバーライドタグ構文(例: {\pos(...)})と衝突するため、
    # 全角文字へ置換して字幕インジェクションを防ぐ。改行は\N(ASSの強制改行制御)で表現する
    # (Dialogue行は1物理行である必要があるため、生の改行文字をそのまま書き込めない)。
    def escape_text(text)
      lines = text.to_s.delete("\r").split("\n", -1).first(MAX_LINES)
      lines
        .map { |line| line.gsub("\\", "＼").gsub("{", "｛").gsub("}", "｝") }
        .join("\\N")
    end

    def format_time(seconds)
      total_cs = (seconds * 100).round
      h = total_cs / 360_000
      m = (total_cs % 360_000) / 6_000
      s = (total_cs % 6_000) / 100
      cs = total_cs % 100
      format("%d:%02d:%02d.%02d", h, m, s, cs)
    end
  end
end
