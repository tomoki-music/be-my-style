require "rails_helper"

RSpec.describe Singing::ShareImageStorageService, type: :service do
  let(:customer) { create(:customer, domain_name: "singing") }
  let(:tmp_dir) { Rails.root.join("tmp/spec/share_image_storage") }
  let(:png_path) { tmp_dir.join("yearly-growth.png") }

  before do
    FileUtils.mkdir_p(tmp_dir)
    File.binwrite(png_path, "PNG")
  end

  after do
    ActiveStorage::Blob.where("key LIKE ?", "singing/share_images/%").find_each(&:purge)
    FileUtils.rm_rf(tmp_dir)
  end

  it "tmp画像をActiveStorageに保存し、公開用に扱えるblob URLを返す" do
    expect do
      result = described_class.call(
        customer: customer,
        capture_target: "yearly-growth",
        local_path: png_path,
        base_url: "https://example.test"
      )

      expect(result.capture_target).to eq("yearly-growth")
      expect(result.filename).to match(/\Ayearly-growth-\d{8}-[0-9a-f]{12}\.png\z/)
      expect(result.filename).not_to include("customer-#{customer.id}")
      expect(result.image_url).to start_with("https://example.test/rails/active_storage/blobs/")
      expect(result.image_url).to include(result.filename)
      expect(result.blob).to be_persisted
      expect(result.blob.key).to start_with("singing/share_images/yearly-growth/")
      expect(result.blob.content_type).to eq("image/png")
      expect(result.blob.metadata).to include("capture_target" => "yearly-growth", "customer_id" => customer.id)
    end.to change(ActiveStorage::Blob, :count).by(1)
  end

  it "存在しないtmp画像は保存しない" do
    blob_count = ActiveStorage::Blob.count

    expect do
      described_class.call(
        customer: customer,
        capture_target: "yearly-growth",
        local_path: tmp_dir.join("missing.png"),
        base_url: "https://example.test"
      )
    end.to raise_error(described_class::MissingImageFile)

    expect(ActiveStorage::Blob.count).to eq(blob_count)
  end

  it "不正なcapture_targetは保存しない" do
    blob_count = ActiveStorage::Blob.count

    expect do
      described_class.call(
        customer: customer,
        capture_target: "ranking",
        local_path: png_path,
        base_url: "https://example.test"
      )
    end.to raise_error(described_class::UnsupportedCaptureTarget)

    expect(ActiveStorage::Blob.count).to eq(blob_count)
  end

  it "public/assetsには生成物を置かない" do
    result = described_class.call(
      customer: customer,
      capture_target: "yearly-growth",
      local_path: png_path,
      base_url: "https://example.test"
    )

    expect(result.blob.key).not_to start_with("public/assets/")
    expect(Rails.root.join("public/assets/#{result.filename}")).not_to exist
  end
end
