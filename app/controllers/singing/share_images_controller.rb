class Singing::ShareImagesController < Singing::BaseController
  before_action :ensure_yearly_growth_report_access!

  def show
    @share_image = Singing::YearlyGrowthShareImageBuilder.call(current_customer)
    unless @share_image.present?
      redirect_to singing_diagnoses_path, alert: "今年の診断がまだないため、シェアカードは表示できません。"
      return
    end

    @share_text = @share_image.x_share_text
    @singer_rank = current_customer.singer_rank
  end

  private

  def ensure_yearly_growth_report_access!
    return if current_customer.has_feature?(:singing_yearly_growth_report)

    redirect_to singing_diagnoses_path, alert: "年間成長レポートのシェアカードはCoreプラン以上で利用できます。"
  end
end
