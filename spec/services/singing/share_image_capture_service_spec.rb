require "rails_helper"

RSpec.describe Singing::ShareImageCaptureService, type: :service do
  let(:year) { Time.current.year }
  let(:customer) { create(:customer, domain_name: "singing") }
  let(:output_root) { Rails.root.join("tmp/spec/share_images") }
  let(:browser) { FakeBrowser.new }

  before do
    customer.create_subscription!(status: "active", plan: "core")
    create(
      :singing_diagnosis,
      :completed,
      customer: customer,
      song_title: "Capture Song",
      created_at: Time.zone.local(year, 1, 10, 10, 0, 0)
    )
  end

  after do
    FileUtils.rm_rf(output_root)
  end

  it "signed token付きのshare_image URLを開き、capture targetだけをpng保存する" do
    result = described_class.call(
      customer: customer,
      base_url: "https://example.test",
      capture_target: "yearly-growth",
      output_root: output_root,
      browser: browser
    )

    expect(result.capture_target).to eq("yearly-growth")
    expect(result.image_url).to be_nil
    relative_path = result.local_path.relative_path_from(Rails.root).to_s
    expect(relative_path).to match(%r{\Atmp/spec/share_images/yearly-growth/#{customer.id}-\d{14}-[0-9a-f]{12}\.png\z})
    expect(File.binread(result.local_path)).to eq("PNG")

    captured = browser.captures.first
    expect(captured.fetch(:url)).to start_with("https://example.test/singing/share_image?")
    expect(captured.fetch(:url)).to include("capture_target=yearly-growth")
    expect(captured.fetch(:url)).to include("capture_token=")
    expect(captured.fetch(:selector)).to eq("[data-share-capture-target='yearly-growth']")
    expect(captured.fetch(:output_path)).to eq(result.local_path)
  end

  it "未対応variantは拒否する" do
    expect do
      described_class.call(
        customer: customer,
        base_url: "https://example.test",
        capture_target: "ranking",
        output_root: output_root,
        browser: browser
      )
    end.to raise_error(described_class::UnsupportedCaptureTarget)
  end

  it "Core未満のユーザーは画像生成できない" do
    customer.subscription.update!(plan: "light")

    expect do
      described_class.call(
        customer: customer,
        base_url: "https://example.test",
        output_root: output_root,
        browser: browser
      )
    end.to raise_error(described_class::AccessDenied)
  end

  it "診断データがない場合は画像生成しない" do
    customer.singing_diagnoses.destroy_all

    expect do
      described_class.call(
        customer: customer,
        base_url: "https://example.test",
        output_root: output_root,
        browser: browser
      )
    end.to raise_error(described_class::NoShareImageData)
  end

  it "古い一時pngをcleanupする" do
    stale_dir = output_root.join("yearly-growth")
    FileUtils.mkdir_p(stale_dir)
    stale_file = stale_dir.join("stale.png")
    File.binwrite(stale_file, "old")
    stale_time = 2.days.ago.to_time
    File.utime(stale_time, stale_time, stale_file)

    described_class.call(
      customer: customer,
      base_url: "https://example.test",
      output_root: output_root,
      browser: browser
    )

    expect(File.exist?(stale_file)).to eq(false)
  end

  class FakeBrowser
    attr_reader :captures

    def initialize
      @captures = []
    end

    def capture_element(url:, selector:, output_path:)
      @captures << { url: url, selector: selector, output_path: output_path }
      FileUtils.mkdir_p(output_path.dirname)
      File.binwrite(output_path, "PNG")
    end
  end
end
