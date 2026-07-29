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
    it "本文中の生HTMLタグをエスケープすること" do
      html = described_class.call("<script>alert(1)</script>", valid_customer_ids: [])
      expect(html).not_to include("<script>")
      expect(html).to include("&lt;script&gt;")
    end

    it "メンションの表示名に含まれるHTML特殊文字もエスケープされること" do
      html = described_class.call("[@<b>太郎</b>](customer:5)", valid_customer_ids: [5])
      expect(html).not_to include("<b>")
      expect(html).to include("&lt;b&gt;")
    end
  end

  it "通常のMarkdown記法(強調等)は展開せずそのまま表示すること" do
    html = described_class.call("**太字にしたい**", valid_customer_ids: [])
    expect(html).to include("**太字にしたい**")
    expect(html).not_to include("<strong>")
  end
end
