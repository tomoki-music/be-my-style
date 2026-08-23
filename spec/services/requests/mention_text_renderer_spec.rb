require "rails_helper"

RSpec.describe Requests::MentionTextRenderer, type: :service do
  describe "個別メンション" do
    it "有効なcustomer_idを.chat-mentionのspanへ変換すること" do
      html = described_class.call("[@太郎](customer:5)お願いします", valid_customer_ids: [5])
      expect(html).to include('<span class="chat-mention" data-customer-id="5">@太郎</span>')
      expect(html).to be_html_safe
    end

    it "valid_customer_idsに含まれないcustomer_idはメンション化せず通常テキストとして表示すること" do
      html = described_class.call("[@太郎](customer:999)", valid_customer_ids: [5])
      expect(html).not_to include('data-customer-id="999"')
      expect(html).to include("@太郎")
      expect(html).not_to include("<span")
    end
  end

  describe "@ALL" do
    it "[@ALL](customer:all)を専用のspanへ変換すること" do
      html = described_class.call("[@ALL](customer:all)", valid_customer_ids: [])
      expect(html).to include('<span class="chat-mention chat-mention--all">@ALL</span>')
    end
  end

  describe "XSS対策" do
    it "本文中の生HTMLタグを除去すること" do
      html = described_class.call("<script>alert(1)</script>", valid_customer_ids: [])
      expect(html).not_to include("<script>")
      expect(html).not_to include("</script>")
    end

    it "メンションの表示名に含まれるHTML特殊文字もエスケープされること" do
      html = described_class.call("[@<b>太郎</b>](customer:5)", valid_customer_ids: [5])
      expect(html).not_to include("<b>")
      expect(html).to include("&lt;b&gt;")
    end

    it "img要素のonerror等のイベント属性を除去すること" do
      html = described_class.call('<img src="x" onerror="alert(1)">', valid_customer_ids: [])
      expect(html).not_to include("onerror")
      expect(html).not_to include("alert(1)")
    end

    it "javascript:スキームのリンクはhrefを無効化すること" do
      html = described_class.call("[危険なリンク](javascript:alert(1))", valid_customer_ids: [])
      expect(html).not_to include("javascript:")
      expect(html).to include("危険なリンク")
    end

    it "httpsリンクは通常のaタグとして表示されること" do
      html = described_class.call("[安全なリンク](https://example.com)", valid_customer_ids: [])
      expect(html).to include('<a href="https://example.com">安全なリンク</a>')
    end

    context "本文中に太字・リスト・安全/危険なリンク・生HTMLが混在する場合" do
      let(:text) do
        <<~MD
          **太字**

          - 項目1
          - 項目2

          [安全なリンク](https://example.com)

          [危険なリンク](javascript:alert(1))

          <script>alert("xss")</script>

          <img src="x" onerror="alert(1)">
        MD
      end
      let(:html) { described_class.call(text, valid_customer_ids: []) }

      it "太字・リスト・httpsリンクはMarkdownとして展開されること" do
        expect(html).to include("<strong>太字</strong>")
        expect(html).to include("<li>項目1</li>")
        expect(html).to include("<li>項目2</li>")
        expect(html).to include('<a href="https://example.com">安全なリンク</a>')
      end

      it "javascript:リンク・script・onerrorはいずれも実行可能な状態で残らないこと" do
        expect(html).not_to include("javascript:")
        expect(html).not_to include("<script>")
        expect(html).not_to include("</script>")
        expect(html).not_to include("onerror")
        expect(html).not_to include('alert(1)')
        # <script>タグ自体は除去されるが、囲まれていたテキスト("alert(\"xss\")")自体はスクリプトとして
        # 実行されない無害な文字列として残る(タグが無い時点でブラウザは評価しない)。
      end
    end

    context "メンションのプレースホルダ復元処理の悪用対策" do
      it "対応するメンションが存在しないプレースホルダ文字列を送っても復元処理で展開されないこと" do
        html = described_class.call("\x02MENTION0\x03", valid_customer_ids: [])
        expect(html).not_to include('<span class="chat-mention"')
      end

      it "正規のメンションと同じインデックスを騙るプレースホルダ文字列を混ぜても、同じ安全なメンションspan以外は出力されないこと" do
        html = described_class.call("[@太郎](customer:5)本文 \x02MENTION0\x03", valid_customer_ids: [5])
        expect(html.scan('<span class="chat-mention" data-customer-id="5">@太郎</span>').size).to eq(2)
        # 生のSTX/ETX制御文字がそのまま出力に残らないこと(任意HTML注入の足がかりにならないこと)
        expect(html).not_to include("\x02")
        expect(html).not_to include("\x03")
      end
    end
  end

  describe "Markdown記法" do
    it "強調(**太字**)がHTMLへ展開されること" do
      html = described_class.call("**太字にしたい**", valid_customer_ids: [])
      expect(html).to include("<strong>太字にしたい</strong>")
    end

    it "メンションと組み合わせてもMarkdown記法が展開されること" do
      html = described_class.call("[@太郎](customer:5)さん **お願いします**", valid_customer_ids: [5])
      expect(html).to include('<span class="chat-mention" data-customer-id="5">@太郎</span>')
      expect(html).to include("<strong>お願いします</strong>")
    end
  end

  describe "改行の保持" do
    it "複数行の入力が改行を保ったまま表示されること" do
      html = described_class.call("1行目\n2行目\n3行目", valid_customer_ids: [])
      expect(html).to include("1行目<br>")
      expect(html).to include("2行目<br>")
      expect(html).to include("3行目")
    end

    it "CRLFの改行もLFと同様に保持されること" do
      html = described_class.call("1行目\r\n2行目", valid_customer_ids: [])
      expect(html).to include("1行目<br>")
      expect(html).to include("2行目")
    end
  end

  it "空文字はhtml_safeな空文字を返すこと" do
    expect(described_class.call("", valid_customer_ids: [])).to eq("")
  end
end
