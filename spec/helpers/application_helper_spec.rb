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
    let(:semi_active_customer) do
      build(:customer, current_sign_in_at: 3.days.ago, is_deleted: false)
    end
    let(:dormant_customer) do
      build(:customer, current_sign_in_at: 2.weeks.ago, is_deleted: false)
    end
    let(:inactive_customer) do
      build(:customer, current_sign_in_at: 2.months.ago, is_deleted: false)
    end
    let(:withdrawn_customer) do
      build(:customer, current_sign_in_at: Time.current, is_deleted: true)
    end

    it 'アクティブユーザーには緑丸(.avatar-active-dot--active)が表示されること' do
      node = fragment(helper.customer_avatar_tag(active_customer))

      expect(node.at_css('.avatar-active-dot')).to be_present
      expect(node.at_css('.avatar-active-dot--active')).to be_present
    end

    it 'ややアクティブなユーザーには黄丸(.avatar-active-dot--semi)が表示されること' do
      node = fragment(helper.customer_avatar_tag(semi_active_customer))

      expect(node.at_css('.avatar-active-dot--semi')).to be_present
      expect(node.at_css('.avatar-active-dot--semi')['title']).to eq '1週間以内にログイン'
    end

    it 'しばらく前にログインしたユーザーには灰丸(.avatar-active-dot--dormant)が表示されること' do
      node = fragment(helper.customer_avatar_tag(dormant_customer))

      expect(node.at_css('.avatar-active-dot--dormant')).to be_present
      expect(node.at_css('.avatar-active-dot--dormant')['title']).to eq '1か月以内にログイン'
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

      expect(dot['title']).to eq '24時間以内にログイン'
      expect(dot['aria-label']).to eq '24時間以内にログイン'
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

    it '通常サイズのアバターでは --small を付けないこと' do
      node = fragment(helper.customer_avatar_tag(active_customer, class_name: 'icon_mini'))

      dot = node.at_css('.avatar-active-dot')
      expect(dot).to be_present
      expect(dot['class']).not_to include('avatar-active-dot--small')
    end

    it '小サイズアバター(class_name が SMALL_AVATAR_IMAGE_CLASSES)には --small を付けること' do
      node = fragment(helper.customer_avatar_tag(active_customer, class_name: 'activity-card-avatar'))

      dot = node.at_css('.avatar-active-dot')
      expect(dot['class']).to include('avatar-active-dot--small')
      # 色・ラベルは通常と共通
      expect(dot['class']).to include('avatar-active-dot--active')
      expect(dot['title']).to eq '24時間以内にログイン'
    end

    it '小サイズ判定は複数クラスのうち1つでも一致すれば有効' do
      node = fragment(helper.customer_avatar_tag(semi_active_customer, class_name: 'foo singing-ranking__user-avatar bar'))

      expect(node.at_css('.avatar-active-dot--small')).to be_present
    end
  end

  describe '#customer_profile_image_tag' do
    before do
      allow(helper).to receive(:image_tag).and_return('<img class="user-profile-image">'.html_safe)
    end

    def fragment(html)
      Nokogiri::HTML.fragment(html)
    end

    let(:customer) { build(:customer, current_sign_in_at: Time.current, is_deleted: false) }

    it '共通枠クラス(.user-profile-image-frame)で画像を包むこと' do
      node = fragment(helper.customer_profile_image_tag(customer))

      frame = node.at_css('span.avatar-with-badge.user-profile-image-frame')
      expect(frame).to be_present
      expect(frame.at_css('img.user-profile-image')).to be_present
    end

    it 'frame_class を追加できること' do
      node = fragment(helper.customer_profile_image_tag(customer, frame_class: 'profile-icon'))

      expect(node.at_css('.user-profile-image-frame.profile-icon')).to be_present
    end

    it 'show_active_status: false でアクティブ丸を抑制できること' do
      node = fragment(helper.customer_profile_image_tag(customer, show_active_status: false))

      expect(node.at_css('.avatar-active-dot')).to be_nil
    end
  end
end
