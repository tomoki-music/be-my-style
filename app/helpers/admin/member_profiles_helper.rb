module Admin::MemberProfilesHelper
  def enum_select(form, field, enum_hash, i18n_scope:)
    options = enum_hash.keys.map do |key|
      [I18n.t("#{i18n_scope}.#{key}", default: key.humanize), key]
    end

    form.select field, options, {}, class: "form-control"
  end
end
