require "rails_helper"

RSpec.describe ActivitiesHelper, type: :helper do
  describe "#activity_markdown" do
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
