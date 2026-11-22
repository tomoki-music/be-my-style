# 退会したアカウントのメールアドレスは、届かない宛先(予約済みドメイン .invalid)へ置き換える。
# どのメーラー(Devise・管理者向けを含む)からでも、その宛先へは送らない最後の防御線。
# 宛先ごとの送信可否は ApplicationMailer#require_notifiable_customer で判定し、ここはそれを補うだけ。
module WithdrawnMailInterceptor
  DOMAIN = "withdrawn.invalid".freeze

  def self.withdrawn_address?(address)
    address.to_s.downcase.end_with?("@#{DOMAIN}")
  end

  def self.delivering_email(message)
    removed = false
    %i[to cc bcc].each do |field|
      addresses = Array(message.public_send(field))
      kept = addresses.reject { |address| withdrawn_address?(address) }
      next if kept.size == addresses.size

      removed = true
      message.public_send("#{field}=", kept.presence)
    end
    return unless removed

    remaining = %i[to cc bcc].sum { |field| Array(message.public_send(field)).size }
    message.perform_deliveries = false if remaining.zero?
    # 宛先アドレスは個人情報のためログに出さない。
    Rails.logger.info("[WithdrawnMailInterceptor] 退会済みアカウントの宛先を除外しました remaining=#{remaining}")
  end
end
