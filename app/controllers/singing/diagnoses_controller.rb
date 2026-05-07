class Singing::DiagnosesController < Singing::BaseController
  before_action :set_diagnosis, only: [:show]
  before_action :set_singing_diagnosis_quota, only: [:new, :create]

  def index
    @diagnoses = current_customer.singing_diagnoses.order(created_at: :desc)
    @polling_required = @diagnoses.any? { |diagnosis| diagnosis.queued? || diagnosis.processing? }
  end

  def new
    @diagnosis = current_customer.singing_diagnoses.build
  end

  def create
    @diagnosis = current_customer.singing_diagnoses.build(diagnosis_params)
    @diagnosis.reference_key = reference_params[:reference_key]
    @diagnosis.reference_bpm = reference_params[:reference_bpm]

    unless current_customer.can_create_singing_diagnosis?
      flash.now[:alert] = "今月の完了済み診断回数を使い切りました。プランをアップグレードすると、引き続き診断を利用できます。"
      render :new
      return
    end

    @diagnosis.status = :queued
    @diagnosis.result_payload = reference_payload

    if @diagnosis.save
      enqueue_submit_to_analyzer_job(@diagnosis)
      redirect_to singing_diagnosis_path(@diagnosis), notice: "歌唱・演奏診断リクエストを受け付けました。"
    else
      render :new
    end
  end

  def show
    @polling_required = @diagnosis.queued? || @diagnosis.processing?
    if @diagnosis.completed?
      @growth_diagnoses = growth_diagnoses_for(@diagnosis)
      @diagnosis_season_badges = latest_season_badges_for(current_customer)
    end
  end

  private

  def set_diagnosis
    @diagnosis = current_customer.singing_diagnoses.find(params[:id])
  end

  def diagnosis_params
    permitted = params.require(:singing_diagnosis).permit(:audio_file, :song_title, :memo, :performance_type, :ranking_opt_in)
    active_types = SingingDiagnosis.performance_type_options.map(&:last)
    permitted[:performance_type] = "vocal" unless active_types.include?(permitted[:performance_type])
    permitted
  end

  def reference_params
    @reference_params ||= params.require(:singing_diagnosis).permit(:reference_key, :reference_bpm)
  end

  def reference_payload
    reference_input = {
      reference_key: reference_params[:reference_key].to_s.strip.presence,
      reference_bpm: reference_params[:reference_bpm].to_s.strip.presence
    }.compact

    reference_input.present? ? { reference_input: reference_input } : nil
  end

  def enqueue_submit_to_analyzer_job(diagnosis)
    job = SingingDiagnoses::SubmitToAnalyzerJob
    job = job.set(priority: 0) if diagnosis.priority_analysis?
    job.perform_later(diagnosis.id)
  end

  def set_singing_diagnosis_quota
    @singing_diagnosis_monthly_limit = current_customer.singing_diagnosis_monthly_limit
    @singing_diagnosis_monthly_count = current_customer.monthly_singing_diagnosis_count
    @singing_diagnosis_remaining_quota = current_customer.remaining_singing_diagnosis_quota
    @singing_diagnosis_quota_limited = current_customer.singing_diagnosis_monthly_limited?
    @singing_diagnosis_quota_exceeded = !current_customer.can_create_singing_diagnosis?
  end

  def growth_diagnoses_for(diagnosis)
    current_customer.singing_diagnoses
      .completed
      .where(performance_type: diagnosis.performance_type)
      .order(created_at: :desc, id: :desc)
      .limit(8)
      .to_a
      .reverse
  end

  def latest_season_badges_for(customer)
    latest_season = SingingRankingSeason.closed.order(ends_on: :desc).first
    return [] unless latest_season

    customer.singing_badges
            .includes(:singing_ranking_season)
            .where(singing_ranking_season: latest_season)
            .order(awarded_at: :desc)
  end
end
