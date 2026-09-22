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
    # MOV(QuickTime)もmp4と同じISO Base Media File Format系のためffprobeは同じ"mov,mp4,..."を返す。
    ALLOWED_FORMAT_NAMES = %w[mp4 mov m4a].freeze
    # 90/270度回転時は表示上の幅と高さが入れ替わる(iPhone等の縦動画で発生)。
    ROTATED_DEGREES = [90, 270].freeze

    # width/height は表示上(=最終的な焼き込み後の映像)の幅・高さ。ffprobeが返す実データの
    # coded width/heightとは、回転90/270度の場合に入れ替わる。rotationは正規化後の角度(0/90/180/270)。
    Result = Struct.new(:duration, :width, :height, :has_audio_stream, :format_name, :rotation, keyword_init: true)

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

      rotation = rotation_degrees(video_stream)
      coded_width = video_stream["width"]
      coded_height = video_stream["height"]
      swapped = ROTATED_DEGREES.include?(rotation)

      Result.new(
        duration: format["duration"]&.to_f,
        width: swapped ? coded_height : coded_width,
        height: swapped ? coded_width : coded_height,
        has_audio_stream: audio_stream.present?,
        format_name: format["format_name"].to_s,
        rotation: rotation
      )
    rescue JSON::ParserError => e
      raise ProbeError, "ffprobe returned invalid JSON: #{e.message}"
    end

    # 回転角度(0/90/180/270)を取得する。iPhone/QuickTimeのMOVは主に2通りの方法で
    # 回転を表現する:
    #   1. 新しいffmpeg: streams[].side_data_list に Display Matrix として rotation(度)が入る
    #   2. 古いffmpeg/一部のファイル: streams[].tags.rotate に文字列で角度が入る
    # 両方を確認し、より新しい side_data_list を優先する。
    def rotation_degrees(stream)
      side_data_list = stream["side_data_list"] || []
      display_matrix = side_data_list.find { |sd| sd["rotation"].present? }
      raw_degrees = display_matrix ? display_matrix["rotation"] : stream.dig("tags", "rotate")

      normalize_degrees(raw_degrees.to_i)
    end

    # Rubyの%は除数が正の場合、負の被除数に対しても非負の結果を返す(-90 % 360 == 270)。
    def normalize_degrees(degrees)
      degrees % 360
    end
  end
end
