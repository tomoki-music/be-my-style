module Chat
  # 保存済みcontentの内部記法 `[@表示名](customer:ID)` を、編集フォームで表示する
  # 自然な `@表示名` へ変換し、既存のMention autocomplete(chat_mention_autocomplete.js)が
  # 使うMention State(customer_id・表示名・出現位置)を復元する。
  #
  # 表示名はcontentに保存された投稿時点の値をそのまま使う(Chat::MarkdownRendererの
  # 表示仕様と同じく、customer_idから最新のnameを引き直さない)。customerの存在確認も
  # 行わない(保存時の可否判定はChat::MentionSyncServiceのeligible_scopeに委ねる)。
  #
  # start/endはJavaScript側(chat_mention_autocomplete.js)のstring.slice相当の
  # UTF-16コード単位オフセットで返す。Rubyの文字数(サロゲートペア文字を1文字と数える)
  # とはズレるため、UTF-16LEへエンコードしてbytesize/2で長さを求めている。
  class MentionHydrator
    MENTION_REGEX = MarkdownRenderer::MENTION_REGEX
    CODE_SEGMENT_REGEX = MarkdownRenderer::CODE_SEGMENT_REGEX

    Result = Struct.new(:content, :mentions, keyword_init: true)

    def self.call(content)
      new(content).hydrate
    end

    def initialize(content)
      @content = content.to_s.first(MarkdownRenderer::MAX_LENGTH)
    end

    def hydrate
      return Result.new(content: @content, mentions: []) if @content.empty?

      mentions = []
      output = +""

      @content.split(CODE_SEGMENT_REGEX).each_with_index do |segment, index|
        if index.odd?
          # コード区間(index.odd?)はChat::MarkdownRendererの表示変換と同様、
          # 中の内部記法を一切変換せず素通しする。
          output << segment
          next
        end

        cursor = 0
        segment.scan(MENTION_REGEX) do
          match = Regexp.last_match
          output << segment[cursor...match.begin(0)]

          username = match[1]
          customer_id = match[2]
          display = "@#{username}"
          start_offset = utf16_length(output)
          output << display
          end_offset = start_offset + utf16_length(display)

          mentions << { customerId: customer_id.to_i, username: username, start: start_offset, end: end_offset }
          cursor = match.end(0)
        end
        output << segment[cursor..]
      end

      Result.new(content: output, mentions: mentions)
    end

    private

    def utf16_length(str)
      str.encode("UTF-16LE").bytesize / 2
    end
  end
end
