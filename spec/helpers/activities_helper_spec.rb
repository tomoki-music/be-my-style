require "rails_helper"

RSpec.describe ActivitiesHelper, type: :helper do
  describe "#activity_markdown" do
    it "ツールバーで入れる斜体・取り消し線・コード・引用・リスト・リンク・画像・区切り線を描画する" do
      text = <<~MD
        *斜体* ~~取り消し~~ `コード`

        > 引用1
        > 引用2

        1. 一つ目
        2. 二つ目

        [リンク名](https://example.com) ![画像の説明](https://example.com/a.png)

        ---

        ```
        <b>コードブロック</b>
        ```
      MD
      html = helper.activity_markdown(text)

      expect(html).to include("<em>斜体</em>", "<del>取り消し</del>", "<code>コード</code>")
      expect(html).to match(%r{<blockquote>\s*<p>引用1<br>\s*引用2</p>\s*</blockquote>})
      expect(html).to include("<li>一つ目</li>", "<li>二つ目</li>")
      expect(html).to include('<a href="https://example.com">リンク名</a>')
      expect(html).to include('<img src="https://example.com/a.png" alt="画像の説明">')
      expect(html).to include("<hr>")
      expect(html).to include("&lt;b&gt;コードブロック&lt;/b&gt;")
    end

    it "チェックリストは記号付きの項目にし、文字色とも併用できる" do
      html = helper.activity_markdown("- [ ] {color:red}未完了{/color}\n- [x] 完了")

      expect(html).to include('<li class="md-task-item">☐ <span class="md-text-color md-text-color--red">未完了</span></li>')
      expect(html).to include('<li class="md-task-item">☑ 完了</li>')
      expect(html).not_to include("<input")
    end

    it "チェックリスト記号への置き換えは活動報告だけで、共通の markdown は従来どおり" do
      expect(helper.markdown("- [ ] やること")).to include("<li>[ ] やること</li>")
    end

    it "太字と許可した文字色を描画する" do
      html = helper.activity_markdown("**太字** と {color:red}赤い文字{/color}")

      expect(html).to include("<strong>太字</strong>")
      expect(html).to include('<span class="md-text-color md-text-color--red">赤い文字</span>')
    end

    it "許可したすべての色を class 付きの span にする" do
      MarkdownTextColors::COLORS.each_key do |color|
        html = helper.activity_markdown("{color:#{color}}文字{/color}")
        expect(html).to include(%(<span class="md-text-color md-text-color--#{color}">文字</span>))
      end
    end

    it "文字色の中の太字・文字色の外の Markdown も従来どおり描画する" do
      html = helper.activity_markdown("## 見出し\n\n{color:blue}**青い太字**{/color}\n\n- 項目")

      expect(html).to include("<h2>見出し</h2>")
      expect(html).to include('<span class="md-text-color md-text-color--blue"><strong>青い太字</strong></span>')
      expect(html).to include("<li>項目</li>")
    end

    it "許可していない色や style 指定は描画せず、文字のまま表示する" do
      html = helper.activity_markdown("{color:pink}ピンク{/color} {color:#ff0000}赤{/color}")

      expect(html).to include("{color:pink}ピンク{/color}")
      expect(html).to include("{color:#ff0000}赤{/color}")
      expect(html).not_to include("<span")
    end

    it "文字色の中の HTML は従来どおり無効化する" do
      html = helper.activity_markdown(%({color:red}<script>alert(1)</script><img src=x onerror=alert(1)>{/color}))

      expect(html).not_to include("<script")
      expect(html).not_to include("onerror")
      expect(html).not_to include("<img")
    end

    it "コード内の記法と改行をまたぐ記法は文字色にしない" do
      html = helper.activity_markdown("`{color:red}コード{/color}`\n\n{color:red}1行目\n2行目{/color}")

      expect(html).to include("<code>{color:red}コード{/color}</code>")
      expect(html).to include("{color:red}1行目")
      expect(html).not_to include("md-text-color")
    end

    it "URL を囲んでもリンク先に目印が混ざらない" do
      html = helper.activity_markdown("{color:red}https://example.com{/color}")

      expect(html).to include('<a href="https://example.com">https://example.com</a>')
      expect(html).to include("md-text-color--red")
      expect(html).not_to include("MDCOLOR")
    end

    it "空のときは空文字を返す" do
      expect(helper.activity_markdown(nil)).to eq("")
      expect(helper.activity_markdown("")).to eq("")
    end
  end

  describe "#activity_plain_text" do
    it "装飾記法を外した文字だけを返す" do
      expect(helper.activity_plain_text("とても**良かった** {color:green}次も{/color}")).to eq("とても良かった 次も")
    end
  end

  describe "MarkdownHelper#markdown(既定)" do
    it "文字色記法を描画しない(活動報告以外の表示は変わらない)" do
      html = helper.markdown("{color:red}文字{/color}")

      expect(html).to include("{color:red}文字{/color}")
      expect(html).not_to include("md-text-color")
    end
  end
end
