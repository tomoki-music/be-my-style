module Business
  module HeaderHelper
    UNREAD_BADGE_MAX = 99

    def business_unread_notification_count(customer = current_customer)
      return 0 if customer.blank?

      customer.passive_notifications.for_business.where(checked: false).count
    end

    def business_unread_badge_label(count)
      count > UNREAD_BADGE_MAX ? "#{UNREAD_BADGE_MAX}+" : count.to_s
    end

    # プロフィール画像があればそれを、未ログイン・未設定・退会済みなら汎用のユーザーアイコンを出す。
    def business_account_icon(customer)
      if customer.present? && !customer_withdrawn?(customer) && customer.profile_image.attached?
        image_tag customer.profile_image, class: "business-account-menu__avatar", alt: ""
      else
        tag.i(class: "fa-solid fa-circle-user business-account-menu__generic-icon", "aria-hidden": "true")
      end
    end
  end
end
