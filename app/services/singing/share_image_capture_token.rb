module Singing
  class ShareImageCaptureToken
    PURPOSE = "singing/share-image-capture".freeze

    class InvalidToken < StandardError; end

    def self.generate(customer:, capture_target:, expires_in: 5.minutes)
      verifier.generate(
        {
          "customer_id" => customer.id,
          "capture_target" => capture_target.to_s
        },
        expires_in: expires_in
      )
    end

    def self.verify(token, capture_target:)
      payload = verifier.verify(token)
      raise InvalidToken unless payload.is_a?(Hash)
      raise InvalidToken unless payload["capture_target"] == capture_target.to_s

      payload
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      raise InvalidToken
    end

    def self.verifier
      Rails.application.message_verifier(PURPOSE)
    end

    private_class_method :verifier
  end
end
