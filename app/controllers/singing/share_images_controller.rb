class Singing::ShareImagesController < Singing::BaseController
  skip_before_action :authenticate_customer!, only: [:show, :public_show]
  skip_before_action :ensure_singing_access!, only: [:show, :public_show]
  before_action :authenticate_share_image_viewer!, only: [:show]
  before_action :ensure_share_image_singing_access!, only: [:show]
  before_action :ensure_supported_capture_target!, only: [:show, :capture]
  before_action :ensure_capture_target_access!, only: [:show, :capture]

  def show
    @capture_target = capture_target
    @share_image = build_share_image
    unless @share_image.present?
      redirect_to singing_diagnoses_path, alert: share_image_unavailable_message
      return
    end

    @share_text = @share_image.x_share_text
    @singer_rank = share_image_customer.singer_rank
    @generated_image_url = params[:generated_image_url].to_s.presence
    @wrapped_year = wrapped_reference_time.year if capture_target == "monthly-wrapped"
    @wrapped_month = wrapped_reference_time.month if capture_target == "monthly-wrapped"
    @wrapped_year = yearly_wrapped_reference_time.year if capture_target == "yearly-wrapped"
  end

  def capture
    result = Singing::ShareImageCaptureService.call(
      customer: current_customer,
      base_url: request.base_url,
      capture_target: capture_target
    )

    render json: {
      capture_target: result.capture_target,
      image_url: result.image_url,
      public_url: result.public_url,
      filename: result.filename,
      local_path: result.local_path.relative_path_from(Rails.root).to_s
    }
  rescue Singing::ShareImageCaptureService::NoShareImageData => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def public_show
    @share_image = SingingShareImage.find_signed!(params[:token], purpose: :public_share_image)
    return render_expired_public_share_image if @share_image.expired_for_public?
    return head :not_found unless @share_image.completed? && @share_image.image.attached?

    @share_title = @share_image.public_title
    @share_description = @share_image.public_description
    @share_og_image_url = rails_blob_url(@share_image.image)
    @debug_ogp = params[:debug_ogp].present?
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    head :not_found
  end

  private

  def render_expired_public_share_image
    @share_title = "このシェア画像は公開期限が終了しました"
    @share_description = "BeMyStyle Singing のシェア画像は一定期間で公開を終了します。"
    render :expired, status: :gone
  end

  def authenticate_share_image_viewer!
    return authenticate_customer! if params[:capture_token].blank?

    payload = Singing::ShareImageCaptureToken.verify(params[:capture_token], capture_target: capture_target)
    @capture_customer = Customer.find_by(id: payload["customer_id"])
    head :not_found unless @capture_customer.present?
  rescue Singing::ShareImageCaptureToken::InvalidToken
    head :not_found
  end

  def ensure_share_image_singing_access!
    customer = share_image_customer
    return if customer&.admin?
    return if customer&.singing_user?
    return if customer&.music_user?

    redirect_to root_path, alert: "音楽または歌唱・演奏診断ドメインの登録が必要です。"
  end

  def ensure_supported_capture_target!
    return if Singing::ShareImageCaptureService::SUPPORTED_TARGETS.key?(capture_target)

    respond_to do |format|
      format.html { head :not_found }
      format.json { render json: { error: "unsupported capture target" }, status: :unprocessable_entity }
    end
  end

  def ensure_capture_target_access!
    if capture_target == "yearly-growth"
      return if share_image_customer.has_feature?(:singing_yearly_growth_report)

      respond_to do |format|
        format.html { redirect_to singing_diagnoses_path, alert: "年間成長レポートのシェアカードはCoreプラン以上で利用できます。" }
        format.json { render json: { error: "年間成長レポートのシェアカードはCoreプラン以上で利用できます。" }, status: :forbidden }
      end
    elsif capture_target == "monthly-wrapped"
      return if share_image_customer.has_feature?(:singing_monthly_wrapped_share_image)

      respond_to do |format|
        format.html { redirect_to singing_diagnoses_path, alert: "Monthly Wrapped シェアカードはCoreプラン以上で利用できます。" }
        format.json { render json: { error: "Monthly Wrapped シェアカードはCoreプラン以上で利用できます。" }, status: :forbidden }
      end
    elsif capture_target == "yearly-wrapped"
      return if share_image_customer.has_feature?(:singing_yearly_wrapped_share_image)

      respond_to do |format|
        format.html { redirect_to singing_diagnoses_path, alert: "Yearly Wrapped はPremiumプランで利用できます。" }
        format.json { render json: { error: "Yearly Wrapped はPremiumプランで利用できます。" }, status: :forbidden }
      end
    end
  end

  def share_image_customer
    @capture_customer || current_customer
  end

  def capture_target
    raw_target = params[:target].presence || params[:capture_target].presence || "yearly-growth"
    raw_target.to_s.tr("_", "-")
  end

  def wrapped_reference_time
    @wrapped_reference_time ||= begin
      year  = params[:year].to_i
      month = params[:month].to_i
      if year.positive? && (1..12).cover?(month)
        Time.zone.local(year, month, 1)
      else
        prev_month = Time.current.beginning_of_month - 1.day
        has_prev = share_image_customer.singing_diagnoses.completed
          .where(created_at: prev_month.all_month).exists?
        has_prev ? prev_month : Time.current
      end
    end
  end

  def yearly_wrapped_reference_time
    @yearly_wrapped_reference_time ||= begin
      year = params[:year].to_i
      year.positive? ? Time.zone.local(year, 6, 1) : Time.current
    end
  end

  def build_share_image
    case capture_target
    when "yearly-growth"
      Singing::YearlyGrowthShareImageBuilder.call(share_image_customer)
    when "daily-challenge"
      Singing::ShareImages::DailyChallengeCardBuilder.call(share_image_customer)
    when "ranking"
      Singing::ShareImages::RankingCardBuilder.call(share_image_customer)
    when "monthly-wrapped"
      Singing::ShareImages::MonthlyWrappedCardBuilder.call(
        share_image_customer,
        reference_time: wrapped_reference_time
      )
    when "yearly-wrapped"
      Singing::ShareImages::YearlyWrappedCardBuilder.call(
        share_image_customer,
        reference_time: yearly_wrapped_reference_time
      )
    end
  end

  def share_image_unavailable_message
    case capture_target
    when "daily-challenge"
      "Daily Challenge のシェアカードはまだ表示できません。"
    when "ranking"
      "ランキングのシェアカードはまだ表示できません。"
    when "monthly-wrapped"
      "この月の診断記録がないため、Monthly Wrapped は表示できません。"
    when "yearly-wrapped"
      "今年の診断記録がないため、Yearly Wrapped は表示できません。"
    else
      "今年の診断がまだないため、シェアカードは表示できません。"
    end
  end
end
