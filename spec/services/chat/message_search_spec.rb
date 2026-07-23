require "rails_helper"

RSpec.describe Chat::MessageSearch, type: :service do
  let(:customer) { create(:customer) }
  let(:chat_room) { create(:chat_room) }

  describe ".call" do
    it "指定したchat_room内のメッセージのみを検索対象にすること" do
      target = create(:chat_message, chat_room: chat_room, customer: customer, content: "今日は練習に行きます")
      other_room = create(:chat_room)
      create(:chat_message, chat_room: other_room, customer: customer, content: "今日は練習に行きます")

      result = described_class.call(chat_room: chat_room, query: "練習")
      expect(result.messages).to contain_exactly(target)
    end

    it "本文の部分一致で検索できること" do
      target = create(:chat_message, chat_room: chat_room, customer: customer, content: "明日のライブ楽しみです")
      create(:chat_message, chat_room: chat_room, customer: customer, content: "全然関係ない内容")

      result = described_class.call(chat_room: chat_room, query: "ライブ")
      expect(result.messages).to contain_exactly(target)
    end

    it "日本語キーワードで検索できること" do
      target = create(:chat_message, chat_room: chat_room, customer: customer, content: "ボーカルの練習をしました")

      result = described_class.call(chat_room: chat_room, query: "ボーカル")
      expect(result.messages).to contain_exactly(target)
    end

    it "スレッド返信も検索対象になること" do
      root = create(:chat_message, chat_room: chat_room, customer: customer, content: "元メッセージ")
      reply = create(:chat_message, chat_room: chat_room, customer: customer, content: "練習の件について返信します", reply_to_chat_message: root)

      result = described_class.call(chat_room: chat_room, query: "練習")
      expect(result.messages).to contain_exactly(reply)
    end

    it "編集後の最新contentがヒットすること" do
      message = create(:chat_message, chat_room: chat_room, customer: customer, content: "元の本文")
      message.update!(content: "編集後の練習内容", edited_at: Time.current)

      result = described_class.call(chat_room: chat_room, query: "練習")
      expect(result.messages).to contain_exactly(message)

      result_old = described_class.call(chat_room: chat_room, query: "元の本文")
      expect(result_old.messages).to be_empty
    end

    it "%をワイルドカードではなくリテラル文字として扱うこと" do
      create(:chat_message, chat_room: chat_room, customer: customer, content: "進捗は50%です")
      create(:chat_message, chat_room: chat_room, customer: customer, content: "進捗は50パーセントです")

      result = described_class.call(chat_room: chat_room, query: "50%")
      expect(result.messages.map(&:content)).to contain_exactly("進捗は50%です")
    end

    it "_をワイルドカードではなくリテラル文字として扱うこと" do
      create(:chat_message, chat_room: chat_room, customer: customer, content: "file_name.txt を送ります")
      create(:chat_message, chat_room: chat_room, customer: customer, content: "fileAname.txt を送ります")

      result = described_class.call(chat_room: chat_room, query: "file_name")
      expect(result.messages.map(&:content)).to contain_exactly("file_name.txt を送ります")
    end

    it "新しい順(created_at DESC)で返すこと" do
      older = create(:chat_message, chat_room: chat_room, customer: customer, content: "練習1", created_at: 2.days.ago)
      newer = create(:chat_message, chat_room: chat_room, customer: customer, content: "練習2", created_at: 1.day.ago)

      result = described_class.call(chat_room: chat_room, query: "練習")
      expect(result.messages.to_a).to eq [newer, older]
    end

    it "1ページ20件でページネーションされること" do
      25.times { |i| create(:chat_message, chat_room: chat_room, customer: customer, content: "検索対象メッセージ#{i}") }

      result = described_class.call(chat_room: chat_room, query: "検索対象")
      expect(result.messages.size).to eq 20
      expect(result.total_count).to eq 25
      expect(result.total_pages).to eq 2

      result_page2 = described_class.call(chat_room: chat_room, query: "検索対象", page: 2)
      expect(result_page2.messages.size).to eq 5
    end

    it "空文字の場合は検索を実行せずstatus: :blankを返すこと" do
      create(:chat_message, chat_room: chat_room, customer: customer, content: "練習の内容")

      result = described_class.call(chat_room: chat_room, query: "")
      expect(result.status).to eq :blank
      expect(result.ok?).to eq false
      expect(result.messages).to be_empty
    end

    it "空白のみの場合はstrip後に空文字としてstatus: :blankを返すこと" do
      result = described_class.call(chat_room: chat_room, query: "   ")
      expect(result.status).to eq :blank
    end

    it "1文字(最小文字数未満)の場合は検索を実行せずstatus: :too_shortを返すこと" do
      create(:chat_message, chat_room: chat_room, customer: customer, content: "a")

      result = described_class.call(chat_room: chat_room, query: "a")
      expect(result.status).to eq :too_short
      expect(result.messages).to be_empty
    end

    it "51文字以上(最大文字数超過)の場合は検索を実行せずstatus: :too_longを返すこと" do
      result = described_class.call(chat_room: chat_room, query: "あ" * 51)
      expect(result.status).to eq :too_long
      expect(result.messages).to be_empty
    end

    it "境界値: 2文字はstatus: :okとなること" do
      create(:chat_message, chat_room: chat_room, customer: customer, content: "ok")
      result = described_class.call(chat_room: chat_room, query: "ok")
      expect(result.status).to eq :ok
    end

    it "境界値: 50文字はstatus: :okとなること" do
      result = described_class.call(chat_room: chat_room, query: "あ" * 50)
      expect(result.status).to eq :ok
    end
  end

  # 本番/開発(MySQL)でのみ発生し、test環境(SQLite)では再現しなかった500エラーの回帰テスト。
  #
  # MySQLは文字列リテラル内でもバックスラッシュをエスケープ文字として解釈するため、
  # `ESCAPE '\'`のようにエスケープ文字をSQL文字列へ直接埋め込むと、閉じクォートとして
  # 機能せず構文エラー(ActiveRecord::StatementInvalid)になる。SQLiteは文字列リテラル内で
  # バックスラッシュを特別扱いしないため、同じ埋め込み方でもtest環境のspecは全て成功して
  # しまい、この回帰を検出できなかった(実際に開発環境のMySQLへ直接実行して発覚した)。
  #
  # test環境がSQLiteである限り、生成されたSQL文字列の見た目だけではこのクラスの不具合を
  # 再現できない(バインド版・埋め込み版のどちらでもSQLite上のto_sqlは同じ表記になる)ため、
  # 実装がエスケープ文字をSQL文字列へ直接埋め込んでいないこと(バインドパラメータとして
  # 渡していること)をソースコードレベルで確認する。
  describe "MySQL/SQLite間のLIKE ESCAPE句の互換性(回帰テスト)" do
    it "ESCAPE句のエスケープ文字をSQL文字列に直接埋め込んでいないこと" do
      source = File.read(Rails.root.join("app/services/chat/message_search.rb"))
      # 例: ESCAPE '\' のような直書きを禁止する(MySQLでは文字列リテラル内のバックスラッシュが
      # エスケープとして解釈され、閉じクォートが機能せず構文エラーになるため)。
      failure_message = "ESCAPE句のエスケープ文字はSQL文字列へ直接埋め込まず、" \
                         "バインドパラメータ(ESCAPE ?)として渡してください"
      expect(source).not_to match(/ESCAPE\s+'\\\\?'/), failure_message
      expect(source).to match(/ESCAPE\s+\?/)
    end

    it "検索語に%やバックスラッシュを含む場合でもMySQL互換のESCAPE ?形式で例外にならないこと" do
      create(:chat_message, chat_room: chat_room, customer: customer, content: "進捗は50%です")

      expect do
        described_class.call(chat_room: chat_room, query: "50%")
      end.not_to raise_error
    end
  end
end
