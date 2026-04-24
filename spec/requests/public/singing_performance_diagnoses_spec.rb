require 'rails_helper'

RSpec.describe "Public::SingingPerformanceDiagnoses", type: :request do
  let(:music_customer) { FactoryBot.create(:customer, domain_name: "music") }
  let(:singing_customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let!(:music_domain) { Domain.find_or_create_by!(name: "music") }
  let!(:singing_domain) { Domain.find_or_create_by!(name: "singing") }

  before do
    CustomerDomain.find_or_create_by!(customer: music_customer, domain: music_domain)
    CustomerDomain.find_or_create_by!(customer: singing_customer, domain: singing_domain)
  end

  describe "GET /public/singing_performance_diagnosis" do
    it "musicユーザーが歌唱・演奏診断の導線ページを表示できること" do
      sign_in music_customer

      get public_singing_performance_diagnosis_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("歌唱・演奏診断")
      expect(response.body).to include(new_singing_diagnosis_path)
      expect(response.body).to include(singing_diagnoses_path)
    end

    it "music以外のユーザーは制限されること" do
      sign_in singing_customer

      get public_singing_performance_diagnosis_path

      expect(response).to redirect_to(singing_root_path)
    end
  end
end
