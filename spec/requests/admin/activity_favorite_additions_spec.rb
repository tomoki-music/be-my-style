require "rails_helper"

RSpec::Matchers.define_negated_matcher :not_change, :change

# 管理画面の活動報告一覧「いいねを追加」(Admin::ActivityFavoriteAdditionsController)。
RSpec.describe "管理画面の活動報告へのいいね追加", type: :request do
  include ActiveJob::TestHelper

  let!(:music_domain) { Domain.find_or_create_by!(name: "music") }

  before { create_owned_favorite_customers }

  let!(:author) { create(:customer) }
  let!(:activity) { create(:activity, customer: author, title: "対象の報告") }
  let!(:other_activity) { create(:activity, customer: author, title: "別の報告") }
  let(:admin) { create(:admin) }
  # Admin 配下は Customer のログインも必要(既存の挙動)。
  let(:operator) { create(:customer) }

  def sign_in_as_admin
    sign_in operator
    sign_in admin
  end

  describe "一覧" do
    before { sign_in_as_admin }

    it "各行の左端に、追加可能な残り件数までのセレクトとボタンを出す" do
      (2..7).each { |id| Favorite.create!(activity: activity, customer_id: id) }

      get admin_activities_path

      row = Nokogiri::HTML(response.body).at_css("#admin-activity-#{activity.id}")
      cells = row.css("> td")
      expect(cells.first.css("option").map(&:text)).to eq(%w[1 2 3])
      expect(cells.first.at_css("input[type=submit]")["value"]).to eq("いいねを追加")
      expect(cells.first.at_css("form")["action"]).to eq(admin_activity_favorite_additions_path(activity))
      expect(cells.first.at_css("form")["data-activity-title"]).to eq("対象の報告")
      expect(cells[1].text.strip).to eq(activity.id.to_s)
      expect(cells[4].text.strip).to eq("6")

      other_row = Nokogiri::HTML(response.body).at_css("#admin-activity-#{other_activity.id}")
      expect(other_row.css("option").map(&:text)).to eq(%w[1 2 3 4 5 6 7 8 9])
    end

    it "残り0件なら「追加可能なアカウントなし」と表示する" do
      (2..10).each { |id| Favorite.create!(activity: activity, customer_id: id) }

      get admin_activities_path

      row = Nokogiri::HTML(response.body).at_css("#admin-activity-#{activity.id}")
      expect(row.css("> td").first.text).to include("追加可能なアカウントなし")
      expect(row.at_css("form")).to be_nil
    end
  end

  describe "追加" do
    it "対象行の記事だけに指定件数を追加し、登録済みの会員を除いて件数を表示する" do
      sign_in_as_admin
      Favorite.create!(activity: activity, customer_id: 3)

      expect do
        post admin_activity_favorite_additions_path(activity), params: { count: 3 }
      end.to change { activity.favorites.count }.by(3)
        .and(not_change { other_activity.favorites.count })
        .and(not_change { Notification.count })
        .and(not_change { enqueued_jobs.size })

      expect(activity.favorites.pluck(:customer_id)).to match_array([2, 3, 4, 5])
      expect(response).to redirect_to(admin_activities_path)
      follow_redirect!
      expect(response.body).to include("いいねを3件追加しました")
      row = Nokogiri::HTML(response.body).at_css("#admin-activity-#{activity.id}")
      expect(row.css("> td")[4].text.strip).to eq("4")
    end

    it "フォームから会員 ID を送っても無視し、サーバー側で決めた会員を使う" do
      sign_in_as_admin
      post admin_activity_favorite_additions_path(activity), params: { count: 1, customer_id: author.id, customer_ids: [author.id] }

      expect(activity.favorites.pluck(:customer_id)).to eq([2])
    end

    it "候補が足りなければ登録せず、理由を表示する" do
      sign_in_as_admin
      (2..9).each { |id| Favorite.create!(activity: activity, customer_id: id) }

      expect { post admin_activity_favorite_additions_path(activity), params: { count: 2 } }.not_to change(Favorite, :count)
      follow_redirect!
      expect(response.body).to include("追加可能なアカウントは残り1件です")
    end

    it "件数が範囲外なら登録しない" do
      sign_in_as_admin
      expect { post admin_activity_favorite_additions_path(activity), params: { count: 10 } }.not_to change(Favorite, :count)
      follow_redirect!
      expect(response.body).to include("1〜9件")
    end

    it "存在しない記事なら登録しない" do
      sign_in_as_admin
      expect { post admin_activity_favorite_additions_path(activity_id: 0), params: { count: 1 } }.not_to change(Favorite, :count)
      follow_redirect!
      expect(response.body).to include("活動報告が見つかりません")
    end

    it "管理者でなければ登録しない" do
      sign_in operator

      expect { post admin_activity_favorite_additions_path(activity), params: { count: 1 } }.not_to change(Favorite, :count)
      expect(response).to have_http_status(:redirect)
      expect(response).not_to redirect_to(admin_activities_path)
    end

    it "GET では受け付けない" do
      expect { Rails.application.routes.recognize_path(admin_activity_favorite_additions_path(activity), method: :get) }
        .to raise_error(ActionController::RoutingError)
    end
  end
end
