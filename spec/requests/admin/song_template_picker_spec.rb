require 'rails_helper'

RSpec.describe "Admin::Events テンプレートpicker", type: :request do
  let(:admin) { FactoryBot.create(:admin) }
  let(:customer) { FactoryBot.create(:customer) }
  let(:community) { FactoryBot.create(:community) }
  let(:event) { FactoryBot.create(:event, :event_with_songs, customer: customer, community: community) }

  before { sign_in admin }

  it "edit画面でテンプレートpickerがエラーなく表示されること(テンプレートあり)" do
    FactoryBot.create(:song_template, community: community, song_name: "テンプレート曲")

    get edit_admin_event_path(event)

    expect(response.status).to eq 200
    expect(response.body).to include("テンプレートから追加")
    expect(response.body).to include("テンプレート曲")
  end

  it "new画面でエラーにならないこと(テンプレートなし)" do
    get new_admin_event_path

    expect(response.status).to eq 200
    expect(response.body).to include("保存済みの楽曲テンプレートはありません。")
  end
end
