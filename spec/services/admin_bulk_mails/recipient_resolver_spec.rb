require "rails_helper"

RSpec.describe AdminBulkMails::RecipientResolver do
  it "退会済み・アドレスなし・無効・メール通知オフ・存在しない ID を理由つきで除外する" do
    ok = FactoryBot.create(:customer)
    withdrawn = FactoryBot.create(:customer).tap { |customer| customer.update_column(:is_deleted, true) }
    no_email = FactoryBot.create(:customer).tap { |customer| customer.update_column(:email, "") }
    invalid = FactoryBot.create(:customer).tap { |customer| customer.update_column(:email, "not-an-address") }
    opted_out = FactoryBot.create(:customer, confirm_mail: false)

    result = described_class.call([ok.id, withdrawn.id, no_email.id, invalid.id, opted_out.id, 0, 999_999].map(&:to_s))

    expect(result.recipients).to eq([ok])
    expect(result.exclusions.map { |exclusion| [exclusion[:customer_id], exclusion[:reason]] }).to contain_exactly(
      [withdrawn.id, :withdrawn], [no_email.id, :no_email], [invalid.id, :invalid_email],
      [opted_out.id, :mail_opt_out], [999_999, :not_found]
    )
  end

  it "ID の重複や数字以外は取り除き、カンマ区切りも受け付ける" do
    a = FactoryBot.create(:customer)
    b = FactoryBot.create(:customer)

    expect(described_class.call(["#{b.id},#{a.id}", a.id.to_s, "x", "1 OR 1=1"]).recipients).to eq([a, b])
  end

  it "未承認のアドレスは送信対象に残し、件数を数えられる" do
    unconfirmed = FactoryBot.create(:customer).tap { |customer| customer.update_column(:confirmed_at, nil) }
    confirmed = FactoryBot.create(:customer)

    result = described_class.call([unconfirmed.id, confirmed.id])

    expect(result.recipients).to contain_exactly(unconfirmed, confirmed)
    expect(result.unconfirmed_recipients).to eq([unconfirmed])
  end

  it "アドレス・メール承認・送信可否が変わると fingerprint が変わる" do
    customer = FactoryBot.create(:customer)
    before = described_class.call([customer.id]).fingerprint("件名", "本文")

    expect(described_class.call([customer.id]).fingerprint("件名", "本文")).to eq(before)
    customer.update_column(:email, "changed@example.com")
    expect(described_class.call([customer.id]).fingerprint("件名", "本文")).not_to eq(before)
  end
end

RSpec.describe AdminBulkMail, ".personalize" do
  it "{{name}} を表示名に置き換え、表示名が空なら「メンバー」にする" do
    named = FactoryBot.build(:customer, name: "山田")
    blank = FactoryBot.build(:customer, name: "  ")

    expect(described_class.personalize("{{name}}さん、{{name}}さんへ", named)).to eq("山田さん、山田さんへ")
    expect(described_class.personalize("{{name}}さん", blank)).to eq("メンバーさん")
    expect(described_class.personalize("{{ name }}と{{NAME}}", named)).to eq("{{ name }}と{{NAME}}")
  end
end
