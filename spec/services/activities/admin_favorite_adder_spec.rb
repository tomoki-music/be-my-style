require "rails_helper"

RSpec.describe Activities::AdminFavoriteAdder do
  include ActiveJob::TestHelper
  let(:admin) { create(:admin) }

  before { create_owned_favorite_customers }

  let!(:author) { create(:customer) }
  let!(:activity) { create(:activity, customer: author) }
  let!(:other_activity) { create(:activity, customer: author) }

  it "未登録の会員を ID の昇順で指定件数だけ追加し、登録済みは除く" do
    Favorite.create!(activity: activity, customer_id: 2)
    Favorite.create!(activity: activity, customer_id: 4)

    result = described_class.call(activity_id: activity.id, count: "3", admin: admin)

    expect(result).to be_success
    expect(result.added_ids).to eq([3, 5, 6])
    expect(activity.favorites.order(:customer_id).pluck(:customer_id)).to eq([2, 3, 4, 5, 6])
    expect(other_activity.favorites).to be_empty
  end

  it "存在しない会員・退会済み・無効・投稿者本人を候補から除く" do
    Customer.find(3).destroy
    Customer.find(5).update_columns(is_deleted: true)
    Customer.find(6).update_columns(is_deleted: true, withdrawn_at: Time.current)
    own_activity = create(:activity, customer: Customer.find(7))

    expect(described_class.candidate_ids(own_activity)).to eq([2, 4, 8, 9, 10])
  end

  it "候補が足りなければ何も登録せず、理由を返す" do
    (2..8).each { |id| Favorite.create!(activity: activity, customer_id: id) }

    result = nil
    expect { result = described_class.call(activity_id: activity.id, count: 3, admin: admin) }.not_to change(Favorite, :count)
    expect(result).not_to be_success
    expect(result.error).to include("残り2件")
  end

  it "候補が0件なら追加可能なアカウントが無いと返す" do
    (2..10).each { |id| Favorite.create!(activity: activity, customer_id: id) }

    result = described_class.call(activity_id: activity.id, count: 1, admin: admin)
    expect(result.error).to eq("追加可能なアカウントがありません。")
  end

  it "件数が1〜9以外・数字以外なら登録しない" do
    ["0", "10", "-1", "abc", "", nil, "2.5"].each do |count|
      result = described_class.call(activity_id: activity.id, count: count, admin: admin)
      expect(result.error).to include("1〜9件"), "count=#{count.inspect}"
    end
    expect(Favorite.count).to eq(0)
  end

  it "存在しない記事なら登録しない" do
    result = described_class.call(activity_id: 0, count: 1, admin: admin)
    expect(result.error).to eq("活動報告が見つかりません。")
    expect(Favorite.count).to eq(0)
  end

  it "通知・メールを作らず、実行者・記事・会員 ID をログに残す" do
    allow(Rails.logger).to receive(:info).and_call_original

    expect { described_class.call(activity_id: activity.id, count: 2, admin: admin) }
      .not_to(change { [Notification.count, ActionMailer::Base.deliveries.size, enqueued_jobs.size] })
    expect(Rails.logger).to have_received(:info)
      .with("[Activities::AdminFavoriteAdder] added admin_id=#{admin.id} activity_id=#{activity.id} customer_ids=2,3")
  end

  it "一覧用の候補をまとめて求める" do
    Favorite.create!(activity: other_activity, customer_id: 2)

    ids = described_class.candidate_ids_by_activity([activity, other_activity])
    expect(ids[activity.id]).to eq((2..10).to_a)
    expect(ids[other_activity.id]).to eq((3..10).to_a)
  end
end
