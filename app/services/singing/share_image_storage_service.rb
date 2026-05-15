require "securerandom"
require "uri"

module Singing
  class ShareImageStorageService
    Result = Struct.new(:capture_target, :share_image, :blob, :filename, :image_url, :public_url, keyword_init: true)

    class UnsupportedCaptureTarget < StandardError; end
    class MissingImageFile < StandardError; end

    def self.call(...)
      new(...).call
    end

    def initialize(customer:, capture_target:, local_path:, base_url:, metadata: {})
      @customer = customer
      @capture_target = capture_target.to_s
      @local_path = Pathname(local_path)
      @base_url = base_url.to_s.delete_suffix("/")
      @metadata = metadata.to_h
    end

    def call
      validate!

      share_image = nil
      share_image = SingingShareImage.create!(
        customer: customer,
        capture_target: capture_target,
        status: :pending,
        expires_at: 7.days.from_now,
        generated_at: Time.current,
        metadata: share_image_metadata
      )

      blob = File.open(local_path, "rb") do |file|
        ActiveStorage::Blob.create_and_upload!(
          io: file,
          filename: filename,
          content_type: "image/png",
          key: storage_key,
          metadata: share_image_metadata,
          identify: false
        )
      end

      share_image.image.attach(blob)
      share_image.update!(status: :completed)

      Result.new(
        capture_target: capture_target,
        share_image: share_image,
        blob: blob,
        filename: filename,
        image_url: blob_url(share_image.image.blob),
        public_url: public_url(share_image)
      )
    rescue StandardError
      share_image&.update(status: :failed) if share_image&.persisted?
      raise
    end

    private

    attr_reader :customer, :capture_target, :local_path, :base_url, :metadata

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

    def share_image_metadata
      {
        capture_target: capture_target,
        generated_at: Time.current.iso8601
      }.merge(metadata)
    end

    def blob_url(blob)
      Rails.application.routes.url_helpers.rails_blob_url(blob, url_options)
    end

    def public_url(share_image)
      token = share_image.signed_id(purpose: :public_share_image)
      Rails.application.routes.url_helpers.singing_public_share_image_url(token, url_options)
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
