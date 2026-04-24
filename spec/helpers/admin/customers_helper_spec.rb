require 'rails_helper'

RSpec.describe Admin::CustomersHelper, type: :helper do
  describe "#domain_badges" do
    it "singingユーザーに歌唱・演奏診断バッヂを表示すること" do
      customer = instance_double(
        Customer,
        music_user?: false,
        business_user?: false,
        learning_user?: false,
        singing_user?: true
      )

      html = helper.domain_badges(customer)

      expect(html).to include("歌唱・演奏診断")
      expect(html).to include("bi-mic")
    end

    it "複数ドメインを持つユーザーの既存バッヂも維持すること" do
      customer = instance_double(
        Customer,
        music_user?: true,
        business_user?: true,
        learning_user?: true,
        singing_user?: true
      )

      html = helper.domain_badges(customer)

      expect(html).to include("音楽")
      expect(html).to include("ビジネス")
      expect(html).to include("学習")
      expect(html).to include("歌唱・演奏診断")
    end
  end
end
