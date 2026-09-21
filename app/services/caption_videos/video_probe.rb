require "open3"
require "json"
require "timeout"

module CaptionVideos
  # ffprobe で動画の実体(コンテナ形式・解像度・長さ・音声トラック有無)を安全に調べる。
  # アップロード時に申告された Content-Type を鵜呑みにせず、ここで実ファイルを検証する。
  class VideoProbe
    class ProbeError < StandardError; end

    PROBE_TIMEOUT_SEC = 30
    # ffprobe の format_name はカンマ区切りで複数candidateを返す(例: "mov,mp4,m4a,3gp,3g2,mj2")。
    ALLOWED_FORMAT_NAMES = %w[mp4 mov m4a].freeze

    Result = Struct.new(:duration, :width, :height, :has_audio_stream, :format_name, keyword_init: true)

    def initialize(path, timeout: PROBE_TIMEOUT_SEC)
      @path = path
      @timeout = timeout
    end

    def call
      stdout, stderr, status = Timeout.timeout(@timeout) do
        Open3.capture3(
          "ffprobe",
          "-v", "error",
          "-print_format", "json",
          "-show_format",
          "-show_streams",
          @path
        )
      end

      unless status.success?
        raise ProbeError, "ffprobe failed: #{stderr.to_s.truncate(500)}"
      end

      parse(stdout)
    rescue Timeout::Error
      raise ProbeError, "ffprobe timeout (#{@timeout}s)"
    rescue Errno::ENOENT
      raise ProbeError, "ffprobe is not installed or not on PATH"
    end

    private

    def parse(json_str)
      data = JSON.parse(json_str)
      format = data["format"] || {}
      streams = data["streams"] || []
      video_stream = streams.find { |s| s["codec_type"] == "video" }
      audio_stream = streams.find { |s| s["codec_type"] == "audio" }

      raise ProbeError, "動画トラックが見つかりません" if video_stream.nil?

      Result.new(
        duration: format["duration"]&.to_f,
        width: video_stream["width"],
        height: video_stream["height"],
        has_audio_stream: audio_stream.present?,
        format_name: format["format_name"].to_s
      )
    rescue JSON::ParserError => e
      raise ProbeError, "ffprobe returned invalid JSON: #{e.message}"
    end
  end
end
