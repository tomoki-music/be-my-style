require "rails_helper"

RSpec.describe Chat::MarkdownRenderer, type: :service do
  def render(text)
    described_class.call(text)
  end

  describe "見出し" do
    it "#/##/### を h1/h2/h3 に変換すること" do
      html = render("# H1\n## H2\n### H3")
      expect(html).to include("<h1>H1</h1>")
      expect(html).to include("<h2>H2</h2>")
      expect(html).to include("<h3>H3</h3>")
    end
  end

  describe "インライン装飾" do
    it "太字・斜体・打ち消しを変換すること" do
      html = render("**bold** *italic* ~~strike~~")
      expect(html).to include("<strong>bold</strong>")
      expect(html).to include("<em>italic</em>")
      expect(html).to include("<del>strike</del>")
    end
  end

  describe "リスト" do
    it "箇条書きリストを ul/li に変換すること" do
      html = render("- AAA\n- BBB")
      expect(html).to include("<ul>")
      expect(html).to include("AAA")
      expect(html).to include("BBB")
    end

    it "番号付きリストを ol/li に変換すること" do
      html = render("1. one\n2. two")
      expect(html).to include("<ol>")
    end
  end

  describe "チェックリスト" do
    it "tightリストの未チェック/チェック済みを input[type=checkbox] に変換すること" do
      html = render("- [ ] task1\n- [x] task2")
      expect(html).to include('<input type="checkbox" disabled')
      expect(html).to match(/task1/)
      expect(html).to match(/<input[^>]*checked[^>]*>\s*task2/)
    end

    it "looseリスト(空行区切り)でも同様に変換すること" do
      html = render("- [ ] task1\n\n- [x] task2")
      expect(html).to include('<input type="checkbox" disabled')
      expect(html).to match(/<input[^>]*checked[^>]*>\s*task2/)
    end
  end

  describe "引用・水平線" do
    it "> を blockquote に変換すること" do
      expect(render("> hello")).to include("<blockquote>")
    end

    it "--- を hr に変換すること" do
      expect(render("foo\n\n---\n\nbar")).to include("<hr>")
    end
  end

  describe "インラインコード・コードブロック" do
    it "バッククォートを code に変換すること" do
      expect(render("`puts 1`")).to include("<code>puts 1</code>")
    end

    it "フェンスコードブロックを Rouge でシンタックスハイライトすること" do
      html = render("```ruby\ndef hello\nend\n```")
      expect(html).to include('<pre class="highlight language-ruby">')
      expect(html).to include("<span")
    end

    it "言語指定がない場合もハイライト用マークアップを崩さず出力すること" do
      html = render("```\nplain text\n```")
      expect(html).to include('<pre class="highlight">')
      expect(html).to include("plain text")
    end
  end

  describe "テーブル" do
    it "GFMテーブル記法を table/thead/tbody に変換すること" do
      html = render("|名前|年齢|\n|---|---|\n|Tomoki|43|")
      expect(html).to include("<table>")
      expect(html).to include("<th>名前</th>")
      expect(html).to include("<td>Tomoki</td>")
    end
  end

  describe "リンク" do
    it "裸のURLを自動リンク化すること" do
      html = render("https://be-my-style.com")
      expect(html).to include('<a href="https://be-my-style.com"')
    end

    it "Markdownリンク記法を変換すること" do
      html = render("[BeMyStyle](https://be-my-style.com)")
      expect(html).to include('<a href="https://be-my-style.com"')
      expect(html).to include(">BeMyStyle</a>")
    end

    it "生成したリンクに rel=noopener noreferrer を付与すること(tabnabbing対策)" do
      html = render("[link](https://example.com)")
      expect(html).to include('rel="noopener noreferrer"')
    end
  end

  describe "画像" do
    it "Markdown画像記法を img タグに変換すること" do
      html = render("![alt](https://example.com/a.png)")
      expect(html).to include('<img src="https://example.com/a.png"')
    end
  end

  describe "絵文字ショートコード" do
    it "GitHub形式のショートコードをUnicode絵文字に変換すること" do
      html = render(":smile: :fire: :guitar: :musical_note:")
      expect(html).to include("😄")
      expect(html).to include("🔥")
      expect(html).to include("🎸")
      expect(html).to include("🎵")
    end

    it "存在しないショートコードはそのまま残すこと" do
      html = render(":not_a_real_emoji_xyz:")
      expect(html).to include(":not_a_real_emoji_xyz:")
    end

    it "インラインコード内のショートコードは変換しないこと" do
      html = render("`:fire:`")
      expect(html).to include("<code>:fire:</code>")
      expect(html).not_to include("🔥")
    end

    it "フェンスコードブロック内のショートコードは変換しないこと" do
      html = render("```\n:fire:\n```")
      expect(html).to include(":fire:")
      expect(html).not_to include("🔥")
    end
  end

  describe "XSS対策" do
    it "script タグを除去し実行不能なテキストにすること" do
      html = render("<script>alert(1)</script>")
      expect(html).not_to include("<script")
    end

    it "iframe タグを除去すること" do
      html = render("<iframe src=evil></iframe>")
      expect(html).not_to include("<iframe")
    end

    it "style タグを除去すること" do
      html = render("<style>body{display:none}</style>")
      expect(html).not_to include("<style")
    end

    it "onerror 等のイベント属性を除去すること" do
      html = render('<img src=x onerror=alert(1)>')
      expect(html).not_to include("onerror")
    end

    it "javascript: リンクを無効化すること" do
      html = render("[xss](javascript:alert(1))")
      expect(html).not_to include('href="javascript:')
    end

    it "フェンスコードブロック内の script タグはエスケープされ非実行テキストとして出力されること" do
      html = render("```\n<script>alert(1)</script>\n```")
      expect(html).to include("&lt;script&gt;")
      expect(html).not_to include("<script>alert(1)</script>")
    end
  end

  describe "空文字・nil" do
    it "nilを渡すと空文字を返すこと" do
      expect(render(nil)).to eq ""
    end

    it "空文字を渡すと空文字を返すこと" do
      expect(render("")).to eq ""
    end
  end

  describe "文字数上限(DoS対策)" do
    it "MAX_LENGTHを超える入力は例外を発生させず、上限までで処理されること" do
      huge_input = "a" * (Chat::MarkdownRenderer::MAX_LENGTH + 10_000)
      expect { render(huge_input) }.not_to raise_error
    end

    it "MAX_LENGTHを超えた部分は切り詰められること" do
      huge_input = ("a" * Chat::MarkdownRenderer::MAX_LENGTH) + "OVER_LIMIT_MARKER"
      expect(render(huge_input)).not_to include("OVER_LIMIT_MARKER")
    end
  end
end
