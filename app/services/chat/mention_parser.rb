module Chat
  # チャットメッセージの本文から `[@表示名](customer:ID)` 記法のメンションIDを抽出する。
  #
  # 生テキストへの正規表現ではなく、Chat::MarkdownRenderer と同じ Redcarpet の
  # パース境界(fenced_code_blocks等)を共有した専用レンダラーでリンクだけを収集する。
  # これにより「コードブロック/インラインコード内は表示上メンション化されない」挙動と、
  # 「メンション作成・通知が飛ぶ対象」を厳密に一致させる。
  class MentionParser
    MENTION_LINK_REGEX = /\Acustomer:(\d+)\z/.freeze

    def self.call(content)
      new(content).extract_customer_ids
    end

    def initialize(content)
      @content = content.to_s.first(MarkdownRenderer::MAX_LENGTH)
    end

    def extract_customer_ids
      return [] if @content.blank?

      collector = CollectorRenderer.new
      Redcarpet::Markdown.new(
        collector,
        autolink: true,
        tables: true,
        fenced_code_blocks: true,
        strikethrough: true,
        no_intra_emphasis: true
      ).render(@content)
      collector.customer_ids.uniq
    end

    class CollectorRenderer < Redcarpet::Render::Base
      attr_reader :customer_ids

      def initialize(*)
        super
        @customer_ids = []
      end

      def link(link, _title, _content)
        match = link.to_s.match(MENTION_LINK_REGEX)
        @customer_ids << match[1].to_i if match
        "" # nilを返すと「未実装」扱いになりRedcarpetのデフォルト処理へフォールバックしてしまうため空文字を返す
      end

      # codespanを実装しないと(未実装=nil相当)、Redcarpetがインラインコード内も
      # 通常のインライン要素として再解釈してしまい、中のlinkコールバックまで呼ばれてしまう。
      # 空文字を明示的に返すことでコード区間として正しく扱われ、中のメンション記法は無視される。
      def codespan(_code)
        ""
      end
    end
  end
end
