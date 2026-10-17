module EventDeadlineReminders
  # 締め切りリマインドの件名・本文をテンプレートとイベント情報から作る(外部生成AIは使わない)。
  # 画面プレビュー・メール・コミュニティチャットのすべてがこの結果を使い、文面を食い違わせない。
  #
  # 本文 = 本文部分(custom_message があればそれ、無ければ自動生成) + 共通フッター(イベント詳細の絶対URL)。
  # 主催者が本文からURLを消しても参加ページへ進めるよう、フッターは常に付ける。件名は常に自動生成。
  #
  # body は出力先でエスケープする前提のプレーンテキスト(メールはHAMLでエスケープ)。
  # chat_body はチャットのMarkdown表示用で、イベント名・カスタム本文などユーザー入力中の
  # Markdown記号をバックスラッシュでエスケープ済み(HTMLはMarkdownRendererのfilter_htmlで無害化)。
  # イベント説明(introduction)は長文・Markdown・HTMLを含みうるため文面に含めない。
  class MessageBuilder
    # main_body: 編集欄に対応する本文部分 / auto_body: 自動生成した本文部分(「編集欄に入れる」用)
    Message = Struct.new(:subject, :body, :chat_body, :main_body, :auto_body, :footer, keyword_init: true)

    # 既存の CustomerMailer / EntryInvitationMailer と同じく本番ホストの絶対URLを使う。
    BASE_URL = "https://be-my-style.com".freeze
    WEEKDAYS = %w[日 月 火 水 木 金 土].freeze
    MARKDOWN_SPECIAL_CHARS = /([\\`*_{}\[\]()#+\-.!|~<>])/.freeze
    # カスタム本文中のURLはチャットで自動リンクされるよう、Markdownエスケープの対象外にする。
    URL_PATTERN = %r{https?://[^\s<>"'`]+}.freeze

    def self.call(**kwargs)
      new(**kwargs).call
    end

    # sent_at: 実際の送信日時(プレビューでは送信予定日時)。「本日」「明日」の判定に使う。
    # custom_message: 主催者が編集した本文(空なら自動生成)。
    def initialize(event:, kind:, sent_at:, custom_message: nil)
      @event = event
      @kind = kind.to_s
      @sent_at = sent_at.in_time_zone(EventDeadlineReminder::TIME_ZONE)
      @custom_message = EventDeadlineReminder.normalize_custom_message(custom_message)
    end

    def call
      auto_body = body_lines { |text| text }.join("\n")
      main_body = @custom_message || auto_body
      chat_main =
        if @custom_message
          escape_markdown_except_urls(@custom_message)
        else
          (["**#{subject_line { |text| escape_markdown(text) }}**", ""] + body_lines { |text| escape_markdown(text) }).join("\n")
        end

      Message.new(
        subject: subject_line { |text| text },
        body: [main_body, footer].join("\n\n"),
        chat_body: [chat_main, footer].join("\n\n"),
        main_body: main_body,
        auto_body: auto_body,
        footer: footer
      )
    end

    # 保存前の新規イベントにはIDが無いため、プレビューでは仮の表記にする(送信時は必ず保存済み)。
    def event_url
      return "#{BASE_URL}/public/events/（保存後に決まります）" unless @event.persisted?

      BASE_URL + Rails.application.routes.url_helpers.public_event_path(@event)
    end

    # 自動生成・カスタム本文のどちらにも必ず付ける。URL行はMarkdown記号を含みうるが、
    # チャットでも自動リンクさせるためエスケープしない(ホストは固定・パスは数値ID)。
    def footer
      label = entry? ? "▼イベント詳細・エントリーはこちら" : "▼イベント詳細・リクエストはこちら"
      "#{label}\n#{event_url}"
    end

    private

    def entry?
      @kind == "entry"
    end

    def deadline
      @deadline ||= (entry? ? @event.event_entry_deadline : @event.request_deadline).in_time_zone(EventDeadlineReminder::TIME_ZONE)
    end

    def deadline_day_label
      case (deadline.to_date - @sent_at.to_date).to_i
      when 0 then "本日"
      when 1 then "明日"
      end
    end

    def subject_line
      prefix = deadline_day_label ? "#{deadline_day_label}締め切り" : "締め切りのお知らせ"
      emoji = entry? ? "🎸" : "🎵"
      topic = entry? ? "エントリー受付" : "曲リクエスト受付"
      "【#{prefix}#{emoji}】#{yield(@event.event_name)}の#{topic}について"
    end

    # ブロックはユーザー入力(イベント名・会場)を出力先に合わせて加工するために使う。
    def body_lines
      topic = entry? ? "エントリー" : "曲リクエスト"
      lines = []
      lines << "みなさん、こんにちは！😊"
      lines << "#{format_date(@event.event_start_time)}開催「#{yield(@event.event_name)}」の#{topic}は、" \
               "#{deadline_day_label}#{format_datetime(deadline)}までです🎵"
      lines << ""
      lines << if entry?
                 "気になる曲や、挑戦してみたいパートがある方は、ぜひチェックしてみてください＾＾"
               else
                 "「この曲をみんなで演奏してみたい！」という曲があれば、ぜひ気軽にリクエストしてみてください＾＾"
               end
      lines << ""
      lines << "📅 開催日時：#{format_event_period}"
      lines << "📍 会場：#{yield(@event.place)}" if @event.place.present?
      lines << "💰 参加費：#{ActiveSupport::NumberHelper.number_to_delimited(@event.entrance_fee)}円" unless @event.entrance_fee.nil?
      lines << "⏰ #{topic}締め切り：#{format_datetime(deadline)}"
      lines << ""
      lines << if entry?
                 "イベントページの楽曲一覧で演奏したい曲のパートにチェックを入れ、" \
                   "「参加確認画面へ」→「参加する」でエントリーしてください😊"
               else
                 "イベントページの「みんなのリクエスト」欄から、演奏してみたい曲を投稿してください😊"
               end
      lines << ""
      lines << "みなさんと音を合わせられるのを楽しみにしています🎶"
      lines
    end

    def format_event_period
      start_time = @event.event_start_time.in_time_zone(EventDeadlineReminder::TIME_ZONE)
      end_time = @event.event_end_time&.in_time_zone(EventDeadlineReminder::TIME_ZONE)
      return format_datetime(start_time) if end_time.blank?

      if start_time.to_date == end_time.to_date
        "#{format_datetime(start_time)}〜#{end_time.strftime('%H:%M')}"
      else
        "#{format_datetime(start_time)}〜#{format_datetime(end_time)}"
      end
    end

    def format_date(time)
      time = time.in_time_zone(EventDeadlineReminder::TIME_ZONE)
      year = time.year == @sent_at.year ? "" : "#{time.year}年"
      "#{year}#{time.month}月#{time.day}日(#{WEEKDAYS[time.wday]})"
    end

    def format_datetime(time)
      time = time.in_time_zone(EventDeadlineReminder::TIME_ZONE)
      "#{format_date(time)} #{time.strftime('%H:%M')}"
    end

    def escape_markdown(text)
      text.to_s.gsub(MARKDOWN_SPECIAL_CHARS) { "\\#{Regexp.last_match(1)}" }
    end

    # カスタム本文はプレーンテキストとして表示する(見出し・リスト・HTML風の記述も文字のまま)。
    def escape_markdown_except_urls(text)
      text.split(/(#{URL_PATTERN})/o).each_with_index.map do |segment, index|
        index.odd? ? segment : escape_markdown(segment)
      end.join
    end
  end
end
