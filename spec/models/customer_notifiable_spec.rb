require "rails_helper"

RSpec.describe Customer, "通知してよい会員の判定" do
  let!(:active) { create(:customer) }
  let!(:deleted) { create(:customer).tap { |customer| customer.update_columns(is_deleted: true) } }
  let!(:withdrawn) { create(:customer).tap { |customer| customer.update_columns(is_deleted: true, withdrawn_at: Time.current) } }

  it "退会(本人の退会・管理画面の退会)した会員を除く" do
    expect(Customer.notifiable).to contain_exactly(active)
    expect(Customer.notifiable_id?(active.id)).to be(true)
    expect(Customer.notifiable_id?(withdrawn.id)).to be(false)
    expect(Customer.notifiable_id?(nil)).to be(false)
    expect([active, deleted, withdrawn].map(&:notifiable?)).to eq([true, false, false])
  end

  # デプロイでコードを置き換えてから db:migrate が終わるまでの間、cron(締め切りリマインド)などの別プロセスが
  # 新しいコードで動いても、まだ無い withdrawn_at 列を参照して送信が失敗しないこと。
  it "withdrawn_at 列がまだ無いときは、is_deleted だけで判定する" do
    allow(Customer).to receive(:column_names).and_return(Customer.column_names - ["withdrawn_at"])

    expect(Customer.notifiable.to_sql).not_to include("withdrawn_at")
    expect(Customer.notifiable).to contain_exactly(active)
  end
end
