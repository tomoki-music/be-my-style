require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  include ActiveSupport::Testing::TimeHelpers

  describe '#customer_avatar_tag のアクティブ状態アイコン' do
    # image_tag はアセット解決に依存するため、アクティブ丸の挙動だけを見たいここではスタブする。
    before do
      allow(helper).to receive(:image_tag).and_return('<img class="avatar-img">'.html_safe)
    end

    def fragment(html)
      Nokogiri::HTML.fragment(html)
    end

    let(:active_customer) do
      build(:customer, current_sign_in_at: Time.current, is_deleted: false)
    end
    let(:inactive_customer) do
      build(:customer, current_sign_in_at: 2.months.ago, is_deleted: false)
    end
    let(:withdrawn_customer) do
      build(:customer, current_sign_in_at: Time.current, is_deleted: true)
    end

    it 'アクティブユーザーには緑丸(.avatar-active-dot)が表示されること' do
      node = fragment(helper.customer_avatar_tag(active_customer))

      expect(node.at_css('.avatar-active-dot')).to be_present
    end

    it '非アクティブユーザーには表示されないこと' do
      node = fragment(helper.customer_avatar_tag(inactive_customer))

      expect(node.at_css('.avatar-active-dot')).to be_nil
    end

    it '退会ユーザーには表示されないこと' do
      node = fragment(helper.customer_avatar_tag(withdrawn_customer))

      expect(node.at_css('.avatar-active-dot')).to be_nil
    end

    it 'show_active_status: false では表示されないこと' do
      node = fragment(helper.customer_avatar_tag(active_customer, show_active_status: false))

      expect(node.at_css('.avatar-active-dot')).to be_nil
    end

    it 'アクセシビリティ属性(title / aria-label / role)が付くこと' do
      dot = fragment(helper.customer_avatar_tag(active_customer)).at_css('.avatar-active-dot')

      expect(dot['title']).to eq '最近アクティブ'
      expect(dot['aria-label']).to eq '最近アクティブ'
      expect(dot['role']).to eq 'img'
    end

    it '正確なログイン日時や「○日前」を出力しないこと' do
      travel_to(Time.zone.local(2026, 8, 27, 12, 0, 0)) do
        customer = build(:customer, current_sign_in_at: Time.zone.local(2026, 8, 20, 9, 30, 0))
        html = helper.customer_avatar_tag(customer)

        expect(html).not_to include('2026')
        expect(html).not_to match(/日前|時間前/)
      end
    end

    it '役職バッジ(管理者)とアクティブ丸が共存できること' do
      allow(active_customer).to receive(:admin?).and_return(true)
      node = fragment(helper.customer_avatar_tag(active_customer))

      expect(node.at_css('.avatar-role-badge')).to be_present
      expect(node.at_css('.avatar-active-dot')).to be_present
    end

    it '既存のラッパー構造(.avatar-with-badge)を壊さないこと' do
      node = fragment(helper.customer_avatar_tag(active_customer))

      expect(node.at_css('span.avatar-with-badge')).to be_present
      expect(node.at_css('.avatar-with-badge .avatar-img')).to be_present
    end

    it 'nil を渡してもエラーにならず丸も出ないこと' do
      html = helper.customer_avatar_tag(nil)

      expect(fragment(html).at_css('.avatar-active-dot')).to be_nil
    end
  end
end
