require "fileutils"
require "securerandom"

module Singing
  class ShareImageCaptureService
    Result = Struct.new(:capture_target, :local_path, :image_url, :public_url, :filename, :share_image, keyword_init: true)

    SUPPORTED_TARGETS = {
      "yearly-growth" => {
        feature: :singing_yearly_growth_report,
        selector: "[data-share-capture-target='yearly-growth']",
        path_helper: :singing_share_image_path
      }
    }.freeze

    class UnsupportedCaptureTarget < StandardError; end
    class AccessDenied < StandardError; end
    class NoShareImageData < StandardError; end

    def self.call(...)
      new(...).call
    end

    def initialize(customer:, base_url:, capture_target: "yearly-growth", output_root: Rails.root.join("tmp/share_images"), browser: nil)
      @customer = customer
      @base_url = base_url.to_s.delete_suffix("/")
      @capture_target = capture_target.to_s.presence || "yearly-growth"
      @output_root = Pathname(output_root)
      @browser = browser
      @owns_browser = browser.nil?
    end

    def call
      validate!
      cleanup_stale_files
      FileUtils.mkdir_p(output_dir)

      active_browser.capture_element(
        url: capture_url,
        selector: target_config.fetch(:selector),
        output_path: output_path
      )

      storage_result = Singing::ShareImageStorageService.call(
        customer: customer,
        capture_target: capture_target,
        local_path: output_path,
        base_url: base_url,
        metadata: storage_metadata
      )

      Result.new(
        capture_target: capture_target,
        local_path: output_path,
        image_url: storage_result.image_url,
        public_url: storage_result.public_url,
        filename: storage_result.filename,
        share_image: storage_result.share_image
      )
    ensure
      active_browser.close if owns_browser && defined?(@active_browser) && @active_browser.present?
    end

    private

    attr_reader :customer, :base_url, :capture_target, :output_root, :browser, :owns_browser

    def validate!
      raise UnsupportedCaptureTarget, "unsupported capture target: #{capture_target}" unless target_config
      raise AccessDenied, "share image capture is not available for this plan" unless customer&.has_feature?(target_config.fetch(:feature))
      raise NoShareImageData, "share image data is not ready" unless share_image_present?
    end

    def target_config
      SUPPORTED_TARGETS[capture_target]
    end

    def share_image_present?
      share_image_data.present?
    end

    def share_image_data
      @share_image_data ||= case capture_target
                            when "yearly-growth"
                              Singing::YearlyGrowthShareImageBuilder.call(customer)
                            end
    end

    def storage_metadata
      return {} unless capture_target == "yearly-growth" && share_image_data.present?

      {
        title: "#{share_image_data.report.year}年 歌声成長レポート",
        season: share_image_data.report.year,
        share_text: share_image_data.x_share_text,
        diagnosis_count: share_image_data.report.diagnosis_count,
        top_growth_label: share_image_data.report.top_growth&.label,
        growth_delta_label: share_image_data.growth_delta_label
      }.compact
    end

    def capture_url
      token = Singing::ShareImageCaptureToken.generate(customer: customer, capture_target: capture_target)
      path = Rails.application.routes.url_helpers.public_send(
        target_config.fetch(:path_helper),
        capture_target: capture_target,
        capture_token: token
      )

      "#{base_url}#{path}"
    end

    def output_dir
      output_root.join(capture_target)
    end

    def output_path
      @output_path ||= output_dir.join("#{customer.id}-#{Time.current.strftime('%Y%m%d%H%M%S')}-#{SecureRandom.hex(6)}.png")
    end

    def active_browser
      @active_browser ||= browser || SeleniumElementScreenshotter.new
    end

    def cleanup_stale_files
      return unless output_root.exist?

      Dir.glob(output_root.join("*/*.png")).each do |path|
        File.delete(path) if File.file?(path) && File.mtime(path) < 24.hours.ago
      end
    end

    class SeleniumElementScreenshotter
      def initialize(width: 1200, height: 900)
        @width = width
        @height = height
      end

      def capture_element(url:, selector:, output_path:)
        require "selenium/webdriver"

        driver.navigate.to(url)
        driver.manage.window.resize_to(@width, @height)
        element = driver.find_element(css: selector)
        element.save_screenshot(output_path.to_s)
      end

      def close
        @driver&.quit
      end

      private

      def driver
        @driver ||= begin
          options = Selenium::WebDriver::Chrome::Options.new
          options.add_argument("--headless=new")
          options.add_argument("--disable-gpu")
          options.add_argument("--no-sandbox")
          options.add_argument("--window-size=#{@width},#{@height}")
          Selenium::WebDriver.for(:chrome, options: options)
        end
      end
    end
  end
end
