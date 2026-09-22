require "open3"
require "timeout"

module CaptionVideos
  # ASS字幕を元動画へ焼き込む。解像度・アスペクト比は変更せず(スケールフィルタを掛けない)、
  # 音声も維持する。Web再生しやすいよう +faststart を付与する。
  #
  # 回転メタデータを持つ入力(iPhoneの縦動画MOV等)について: ffmpegはmov/mp4デマルチプレクサの
  # autorotate(デフォルト有効、ffmpeg 4.1以降)により、-vfで指定したフィルタの前段で自動的に
  # 回転を適用してから ass= フィルタへ渡す。そのため CaptionVideos::VideoProbe が返す width/height
  # (表示上のサイズ)とこのffmpegの出力は一致する。ここで明示的な transpose/rotate フィルタを
  # 追加すると二重回転になるため、絶対に追加しないこと。
  class VideoRenderer
    class RenderError < StandardError; end

    RENDER_TIMEOUT_SEC = ENV.fetch("CAPTION_VIDEO_RENDER_TIMEOUT_SEC", 3600).to_i
    MAX_ERROR_LENGTH = 1000

    def initialize(input_path:, ass_path:, output_path:, timeout: RENDER_TIMEOUT_SEC)
      @input_path = input_path
      @ass_path = ass_path
      @output_path = output_path
      @timeout = timeout
    end

    def call
      _stdout, stderr, status = Timeout.timeout(@timeout) do
        Open3.capture3(
          "ffmpeg",
          "-y",
          "-i", @input_path,
          "-vf", "ass=#{escaped_filter_path(@ass_path)}",
          "-c:v", "libx264",
          "-preset", "veryfast",
          "-crf", "20",
          "-c:a", "aac",
          "-b:a", "128k",
          "-movflags", "+faststart",
          @output_path
        )
      end

      unless status.success?
        raise RenderError, "render failed: #{stderr.to_s.truncate(MAX_ERROR_LENGTH)}"
      end

      unless File.exist?(@output_path) && File.size?(@output_path)
        raise RenderError, "render output is missing or empty"
      end

      true
    rescue Timeout::Error
      raise RenderError, "render timeout (#{@timeout}s)"
    rescue Errno::ENOENT
      raise RenderError, "ffmpeg is not installed or not on PATH"
    end

    private

    # ffmpegのフィルタグラフ構文では ':' がオプション区切りとして解釈されるためエスケープする。
    # ass_path/input_pathはいずれもDir.mktmpdirで生成した一時ファイルパスであり、
    # ユーザー入力(ファイル名等)が直接混入することはない。
    def escaped_filter_path(path)
      path.to_s.gsub("\\", "\\\\\\\\").gsub(":", "\\:")
    end
  end
end
