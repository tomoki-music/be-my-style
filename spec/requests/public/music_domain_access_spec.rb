require 'rails_helper'

RSpec.describe "Public music domain access", type: :request do
  let(:music_customer) { FactoryBot.create(:customer, domain_name: "music") }
  let(:singing_customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let!(:music_domain) { Domain.find_or_create_by!(name: "music") }
  let!(:singing_domain) { Domain.find_or_create_by!(name: "singing") }

  before do
    CustomerDomain.find_or_create_by!(customer: music_customer, domain: music_domain)
    CustomerDomain.find_or_create_by!(customer: singing_customer, domain: singing_domain)
  end

  it "musicユーザーは音楽プラットフォームにアクセスできること" do
    sign_in music_customer

    get public_homes_top_path

    expect(response).to have_http_status(:ok)
  end

  it "singingのみのユーザーは音楽プラットフォームから歌唱・演奏診断トップへ戻されること" do
    sign_in singing_customer

    get public_homes_top_path

    expect(response).to redirect_to(singing_root_path)
  end

  it "singingのみのユーザーも共通の料金ページは確認できること" do
    sign_in singing_customer

    get public_lp_path

    expect(response).to have_http_status(:ok)
  end
end
