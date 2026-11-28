# 当日受付の集金チェック票。対象はイベント詳細の「参加メンバー」欄と同じ会員(Event#join_members)。
# 閲覧・更新とも Customer#can_manage_event_payment_checks?(システム管理者+主催コミュニティのオーナー)で確認する。
# 集金状況の記録だけを扱い、エントリー・参加人数・参加費の計算には触れない。
class Public::EventPaymentChecksController < ApplicationController
  before_action :authenticate_customer!
  before_action :set_event
  before_action :authorize_payment_checks!

  def index
    @members = @event.join_members
    ActiveRecord::Associations::Preloader.new.preload(@members, profile_image_attachment: :blob)
    @checks_by_customer_id = @event.payment_checks.includes(:updated_by).index_by(&:customer_id)
    @collected_count = @members.count { |member| @checks_by_customer_id[member.id]&.collected? }
    @last_check = @checks_by_customer_id.values_at(*@members.map(&:id)).compact.max_by(&:updated_at)

    # 金額は記録せず、表示のたびに既存の参加費計算(Event#participant_remaining_fee_for)から出す。
    # そのため参加費や特典の適用が後から変わると表示額も変わる(実際に受け取った金額の記録ではない)。
    # entrance_fee は NOT NULL・必須入力のため「金額未設定」は無く、0円は集金不要として扱う。
    @fees_by_customer_id = @members.to_h { |member| [member.id, @event.participant_remaining_fee_for(member)] }
    @expected_total = @fees_by_customer_id.values.sum
    @collected_total = @members.sum { |member| @checks_by_customer_id[member.id]&.collected? ? @fees_by_customer_id[member.id] : 0 }
    @uncollected_total = @expected_total - @collected_total
  end

  def update
    # URL の会員がこのイベントの「参加メンバー」でなければ更新しない(他イベントの参加者・無関係な会員を含む)。
    customer = @event.join_members.find { |member| member.id.to_s == params[:customer_id].to_s }
    return redirect_to(public_event_payment_checks_path(@event), alert: "このイベントの参加メンバーではないため、集金状況を変更できません。") if customer.nil?

    collected = ActiveModel::Type::Boolean.new.cast(params[:collected]) == true
    save_check!(customer, collected)

    # 保存結果は行の色とボタン表示で分かるため、合計欄に重なる一時通知は出さない。
    redirect_to public_event_payment_checks_path(@event, anchor: "payment-check-#{customer.id}")
  end

  private

  def set_event
    @event = Event.includes(songs: :join_parts).find(params[:event_id])
  end

  def authorize_payment_checks!
    return if current_customer.can_manage_event_payment_checks?(@event)

    redirect_to public_event_path(@event), alert: "このイベントの集金チェック票を見る権限がありません。"
  end

  def save_check!(customer, collected)
    attempts = 0
    begin
      check = @event.payment_checks.find_or_initialize_by(customer_id: customer.id)
      check.update!(collected: collected, updated_by: current_customer)
    rescue ActiveRecord::RecordNotUnique
      # 同時に2台の端末で初めてチェックした場合は、先に作られた行を更新し直す。
      attempts += 1
      retry if attempts < 2
      raise
    end
  end
end
