class Singing::ShareImagesController < Singing::BaseController
  skip_before_action :authenticate_customer!, only: [:show]
  skip_before_action :ensure_singing_access!, only: [:show]
  before_action :authenticate_share_image_viewer!, only: [:show]
  before_action :ensure_share_image_singing_access!, only: [:show]
  before_action :ensure_supported_capture_target!
  before_action :ensure_yearly_growth_report_access!

  def show
    @share_image = Singing::YearlyGrowthShareImageBuilder.call(share_image_customer)
    unless @share_image.present?
      redirect_to singing_diagnoses_path, alert: "今年の診断がまだないため、シェアカードは表示できません。"
      return
    end

    @share_text = @share_image.x_share_text
    @singer_rank = share_image_customer.singer_rank
    @generated_image_url = params[:generated_image_url].to_s.presence
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
      local_path: result.local_path.relative_path_from(Rails.root).to_s
    }
  rescue Singing::ShareImageCaptureService::NoShareImageData => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

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

  def ensure_yearly_growth_report_access!
    return if share_image_customer.has_feature?(:singing_yearly_growth_report)

    respond_to do |format|
      format.html { redirect_to singing_diagnoses_path, alert: "年間成長レポートのシェアカードはCoreプラン以上で利用できます。" }
      format.json { render json: { error: "年間成長レポートのシェアカードはCoreプラン以上で利用できます。" }, status: :forbidden }
    end
  end

  def share_image_customer
    @capture_customer || current_customer
  end

  def capture_target
    params[:capture_target].presence || "yearly-growth"
  end
end
