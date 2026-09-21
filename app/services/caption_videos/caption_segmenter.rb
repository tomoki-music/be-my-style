module CaptionVideos
  # OpenAI Whisper の segment(文/フレーズ単位)を、画面表示に適したテロップ単位へ整形する。
  # 発言内容は要約・変更しない。文字数の都合で1 segmentを複数テロップへ分割する場合、
  # 各テロップの開始/終了時刻は元segment内で文字数に比例配分し、時刻が重複・逆転しないようにする。
  class CaptionSegmenter
    LINE_MAX_CHARS = 20
    MAX_LINES = 2
    CAPTION_MAX_CHARS = LINE_MAX_CHARS * MAX_LINES
    MIN_CAPTION_SECONDS = 0.3
    # 分割候補にする句読点・区切り記号(この直後で切ると自然な区切りになりやすい)。
    SPLIT_CHARS = %w[。 ! ? ！ ? 、 ,].freeze
    LINE_BREAK_CHARS = %w[。 、 ! ? ！ ?].freeze

    def self.call(segments)
      new(segments).call
    end

    def initialize(segments)
      @segments = Array(segments)
    end

    def call
      @segments.flat_map { |segment| build_captions_for(segment) }
    end

    private

    def build_captions_for(segment)
      text = segment[:text].to_s.strip
      return [] if text.blank?

      start_time = segment[:start].to_f
      end_time = segment[:end].to_f
      return [] if end_time <= start_time

      chunks = split_long_text(text)
      times = allocate_times(chunks, start_time, end_time)

      chunks.each_with_index.map do |chunk, i|
        {
          start_time: times[i][0].round(3),
          end_time: times[i][1].round(3),
          text: wrap_into_lines(chunk)
        }
      end
    end

    # CAPTION_MAX_CHARS を超えるテキストを、句読点付近を優先して分割する。
    def split_long_text(text)
      return [text] if text.length <= CAPTION_MAX_CHARS

      chunks = []
      remaining = text
      until remaining.empty?
        if remaining.length <= CAPTION_MAX_CHARS
          chunks << remaining
          break
        end

        cut = best_cut_index(remaining, CAPTION_MAX_CHARS)
        chunks << remaining[0...cut]
        remaining = remaining[cut..-1].to_s
      end
      chunks
    end

    # limit文字以内で、できるだけ句読点の直後を分割点にする。見つからなければlimitで機械的に切る。
    def best_cut_index(text, limit)
      window = text[0...limit]
      SPLIT_CHARS.each do |char|
        idx = window.rindex(char)
        next if idx.nil?

        cut = idx + 1
        return cut if cut >= (limit / 2.0).ceil # 極端に短い分割は避ける
      end
      limit
    end

    # LINE_MAX_CHARSを超える場合、中央付近の句読点/文字境界で改行を1つ入れる(最大2行)。
    def wrap_into_lines(text)
      return text if text.length <= LINE_MAX_CHARS

      idx = best_cut_index(text, LINE_MAX_CHARS)
      idx = LINE_MAX_CHARS if idx <= 0 || idx >= text.length
      "#{text[0...idx]}\n#{text[idx..-1]}"
    end

    # 各チャンクの文字数比率で元segmentの時間幅を配分する。時刻は単調増加を保証する。
    def allocate_times(chunks, start_time, end_time)
      total_span = end_time - start_time
      total_chars = chunks.sum(&:length)
      total_chars = 1 if total_chars.zero?

      cursor = start_time
      times = []
      chunks.each_with_index do |chunk, i|
        if i == chunks.length - 1
          chunk_end = end_time
        else
          share = chunk.length.to_f / total_chars * total_span
          share = MIN_CAPTION_SECONDS if share < MIN_CAPTION_SECONDS
          chunk_end = [cursor + share, end_time].min
        end
        chunk_end = cursor + MIN_CAPTION_SECONDS if chunk_end <= cursor
        times << [cursor, chunk_end]
        cursor = chunk_end
      end
      times
    end
  end
end
