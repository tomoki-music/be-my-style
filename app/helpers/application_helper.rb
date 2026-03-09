module ApplicationHelper

  def admin?
    customer_signed_in? && current_customer.admin?
  end

  def enum_filter_options(enum_hash, i18n_scope)
    [["全て", ""]] +
      enum_hash.keys.map { |k| [I18n.t("#{i18n_scope}.#{k}"), k] }
  end
  
  def html_safe_newline(str)
    h(str).gsub(/\n|\r|\r\n/, "<br>").html_safe
  end
  
end
