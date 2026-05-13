class Singing::AiChallengeProgressesController < Singing::BaseController
  def update
    unless current_customer.has_feature?(:singing_ai_challenge_progress)
      redirect_to redirect_path, alert: "AIチャレンジの進捗保存はCoreプラン以上で利用できます。"
      return
    end

    progress = current_progress_finder.find_or_create!

    if progress.update(progress_params)
      redirect_to redirect_path, notice: "AIチャレンジの進捗を保存しました"
    else
      redirect_to redirect_path, alert: "AIチャレンジの進捗を保存できませんでした。"
    end
  end

  private

  def current_progress_finder
    @current_progress_finder ||= SingingDiagnoses::MonthlyAiChallengeProgressFinder.new(
      current_customer,
      challenge: current_monthly_ai_challenge
    )
  end

  def current_monthly_ai_challenge
    @current_monthly_ai_challenge ||= begin
      report = SingingDiagnoses::MonthlyGrowthReport.new(current_customer).call
      SingingDiagnoses::MonthlyAiChallenge.new(current_customer, growth_report: report).call
    end
  end

  def progress_params
    params
      .fetch(:singing_ai_challenge_progress, {})
      .permit(:tried, :completed, :next_diagnosis_planned)
  end

  def redirect_path
    diagnosis = current_customer.singing_diagnoses.find_by(id: params[:diagnosis_id])
    diagnosis.present? ? singing_diagnosis_path(diagnosis) : singing_diagnoses_path
  end
end
