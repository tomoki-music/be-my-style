require "rails_helper"

RSpec.describe ApplicationController, type: :controller do
  controller do
    def index
      head :ok
    end
  end

  before do
    routes.draw { get "index" => "anonymous#index" }
    Domain.find_or_create_by!(name: "music")
    Domain.find_or_create_by!(name: "business")
    Domain.find_or_create_by!(name: "learning")
    Domain.find_or_create_by!(name: "singing")
  end

  describe "#set_current_domain" do
    it "singing配下ではcurrent domainをsingingにすること" do
      allow(request).to receive(:path).and_return("/singing")

      controller.send(:set_current_domain)

      expect(controller.instance_variable_get(:@current_domain).name).to eq "singing"
    end

    it "business配下ではcurrent domainをbusinessにすること" do
      allow(request).to receive(:path).and_return("/business")

      controller.send(:set_current_domain)

      expect(controller.instance_variable_get(:@current_domain).name).to eq "business"
    end

    it "learning配下ではcurrent domainをlearningにすること" do
      allow(request).to receive(:path).and_return("/learning")

      controller.send(:set_current_domain)

      expect(controller.instance_variable_get(:@current_domain).name).to eq "learning"
    end

    it "その他のpathではcurrent domainをmusicにすること" do
      allow(request).to receive(:path).and_return("/")

      controller.send(:set_current_domain)

      expect(controller.instance_variable_get(:@current_domain).name).to eq "music"
    end
  end
end
