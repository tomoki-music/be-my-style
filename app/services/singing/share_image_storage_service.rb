require "securerandom"
require "uri"

module Singing
  class ShareImageStorageService
    Result = Struct.new(:capture_target, :blob, :filename, :image_url, keyword_init: true)

    class UnsupportedCaptureTarget < StandardError; end
    class MissingImageFile < StandardError; end

    def self.call(...)
      new(...).call
    end

    def initialize(customer:, capture_target:, local_path:, base_url:)
      @customer = customer
      @capture_target = capture_target.to_s
      @local_path = Pathname(local_path)
      @base_url = base_url.to_s.delete_suffix("/")
    end

    def call
      validate!

      blob = File.open(local_path, "rb") do |file|
        ActiveStorage::Blob.create_and_upload!(
          io: file,
          filename: filename,
          content_type: "image/png",
          key: storage_key,
          metadata: metadata,
          identify: false
        )
      end

      Result.new(
        capture_target: capture_target,
        blob: blob,
        filename: filename,
        image_url: blob_url(blob)
      )
    end

    private

    attr_reader :customer, :capture_target, :local_path, :base_url

    def validate!
      unless Singing::ShareImageCaptureService::SUPPORTED_TARGETS.key?(capture_target)
        raise UnsupportedCaptureTarget, "unsupported capture target: #{capture_target}"
      end

      raise MissingImageFile, "share image file does not exist" unless local_path.file?
    end

    def filename
      @filename ||= "#{capture_target}-#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.hex(6)}.png"
    end

    def storage_key
      @storage_key ||= "singing/share_images/#{capture_target}/#{filename}"
    end

    def metadata
      {
        capture_target: capture_target,
        customer_id: customer.id,
        generated_at: Time.current.iso8601
      }
    end

    def blob_url(blob)
      Rails.application.routes.url_helpers.rails_blob_url(blob, url_options)
    end

    def url_options
      return {} if base_url.blank?

      uri = URI.parse(base_url)
      options = { host: uri.host, protocol: "#{uri.scheme}://" }
      options[:port] = uri.port if uri.port && ![80, 443].include?(uri.port)
      options
    rescue URI::InvalidURIError
      { host: base_url }
    end
  end
end
