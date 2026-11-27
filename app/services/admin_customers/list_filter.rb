module AdminCustomers
  # 管理画面 TOP のメンバー一覧の絞り込み。一覧の表示と「条件に一致した人をすべて選択」で同じ条件を使う。
  #
  # 最終ログイン・メール承認は、一覧の列と同じ customers.current_sign_in_at / customers.confirmed_at を見る。
  # 期間はアプリのタイムゾーンで現在から遡る(1ヶ月は暦上の1ヶ月)。境界ちょうどは含める。
  # ログイン履歴のない人(current_sign_in_at が空)は期間を指定したときは含めない。
  class ListFilter
    PROFILE_FILTERS = {
      member_type: :suggested_member_type,
      music_experience_level: :music_experience_level,
      engagement_style: :engagement_style,
      contact_preference: :contact_preference
    }.freeze

    LAST_LOGIN_OPTIONS = {
      "1d" => { label: "1日以内", period: -> { 1.day } },
      "3d" => { label: "3日以内", period: -> { 3.days } },
      "1m" => { label: "1ヶ月以内", period: -> { 1.month } }
    }.freeze

    EMAIL_CONFIRMATION_OPTIONS = {
      "confirmed" => "承認済み",
      "unconfirmed" => "未承認"
    }.freeze

    def self.call(scope, params, now: Time.current)
      new(scope, params, now: now).call
    end

    def initialize(scope, params, now: Time.current)
      @scope = scope
      @params = params
      @now = now.in_time_zone
    end

    def call
      relation = @scope.left_joins(:member_profile)

      PROFILE_FILTERS.each do |param_key, column|
        value = @params[param_key]
        relation = relation.where(member_profiles: { column => value }) if value.present?
      end

      if (threshold = last_login_threshold)
        relation = relation.where("customers.current_sign_in_at >= ?", threshold)
      end

      case @params[:email_confirmation].to_s
      when "confirmed" then relation = relation.where.not(confirmed_at: nil)
      when "unconfirmed" then relation = relation.where(confirmed_at: nil)
      end

      relation
    end

    private

    def last_login_threshold
      option = LAST_LOGIN_OPTIONS[@params[:last_login].to_s]
      option && @now - option[:period].call
    end
  end
end
