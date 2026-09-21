require "open3"
require "timeout"

module CaptionVideos
  # 動画から文字起こし用の音声を抽出する。OpenAI Whisper APIの25MB制限に
  # 収まるよう、モノラル・低ビットレートのMP3に変換する。
  class AudioExtractor
    class ExtractionError < StandardError; end

    EXTRACT_TIMEOUT_SEC = ENV.fetch("CAPTION_VIDEO_AUDIO_TIMEOUT_SEC", 300).to_i
    # Whisper APIの上限(25MB)に対して安全マージンを取る。
    MAX_AUDIO_BYTES = 24.megabytes
    AUDIO_BITRATE = "64k"
    AUDIO_SAMPLE_RATE = "16000"

    def initialize(input_path:, output_path:, timeout: EXTRACT_TIMEOUT_SEC)
      @input_path = input_path
      @output_path = output_path
      @timeout = timeout
    end

    def call
      _stdout, stderr, status = Timeout.timeout(@timeout) do
        Open3.capture3(
          "ffmpeg",
          "-y",
          "-i", @input_path,
          "-vn",
          "-ac", "1",
          "-ar", AUDIO_SAMPLE_RATE,
          "-b:a", AUDIO_BITRATE,
          "-f", "mp3",
          @output_path
        )
      end

      unless status.success?
        raise ExtractionError, "audio extraction failed: #{stderr.to_s.truncate(500)}"
      end

      unless File.exist?(@output_path) && File.size?(@output_path)
        raise ExtractionError, "extracted audio is missing or empty"
      end

      if File.size(@output_path) > MAX_AUDIO_BYTES
        raise ExtractionError, "extracted audio exceeds size limit (#{File.size(@output_path)} bytes)"
      end

      true
    rescue Timeout::Error
      raise ExtractionError, "audio extraction timeout (#{@timeout}s)"
    rescue Errno::ENOENT
      raise ExtractionError, "ffmpeg is not installed or not on PATH"
    end
  end
end
