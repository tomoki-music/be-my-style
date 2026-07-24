require "rails_helper"

RSpec.describe Chat::LinkPreviewHostConfig, type: :service do
  describe ".normalize" do
    it "nilはArray(...)により空配列になること" do
      expect(described_class.normalize(nil)).to eq []
    end

    it "空配列は空配列のままであること" do
      expect(described_class.normalize([])).to eq []
    end

    it "カンマ区切り文字列をstrip・downcase・空要素除去・重複排除すること" do
      result = described_class.normalize(" Be-My-Style.com , ,www.BE-MY-STYLE.com, be-my-style.com ,")
      expect(result).to eq %w[be-my-style.com www.be-my-style.com]
    end

    it "空白のみの文字列は空配列になること" do
      expect(described_class.normalize("   ")).to eq []
    end

    it "配列を渡した場合もstrip・downcase・重複排除すること" do
      result = described_class.normalize([" Localhost ", "localhost", ""])
      expect(result).to eq ["localhost"]
    end
  end

  describe ".default_hosts_for" do
    it "productionでは本番ホストのみを返すこと(テスト用ホストを含まない)" do
      hosts = described_class.default_hosts_for("production")
      expect(hosts).to eq %w[be-my-style.com www.be-my-style.com]
      expect(hosts).not_to include("www.example.com")
      expect(hosts).not_to include("localhost")
    end

    it "testではwww.example.comのみを返すこと" do
      expect(described_class.default_hosts_for("test")).to eq %w[www.example.com]
    end

    it "development(その他の環境)では本番ホスト+localhostを返すこと" do
      hosts = described_class.default_hosts_for("development")
      expect(hosts).to include("be-my-style.com", "www.be-my-style.com", "localhost")
    end
  end

  describe ".resolve" do
    it "ENV未設定の場合は環境別デフォルトを返すこと" do
      expect(described_class.resolve(env_value: nil, rails_env: "production")).to eq %w[be-my-style.com www.be-my-style.com]
    end

    it "ENVが空文字の場合も環境別デフォルトにフォールバックすること" do
      expect(described_class.resolve(env_value: "  , ,", rails_env: "test")).to eq %w[www.example.com]
    end

    it "ENV設定時はその値(正規化済み)を優先すること" do
      result = described_class.resolve(env_value: "Foo.example, bar.example", rails_env: "production")
      expect(result).to eq %w[foo.example bar.example]
    end

    it "戻り値がnilになることはないこと" do
      expect(described_class.resolve(env_value: nil, rails_env: "unknown")).to be_a(Array)
    end
  end
end
