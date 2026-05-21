class Admin::Singing::RecapMovieBatchExecutionsController < ApplicationController
  skip_before_action :authenticate_customer!
  skip_before_action :ensure_music_domain_access_for_public_routes!, raise: false
  before_action :authenticate_admin!
  before_action :set_execution

  VALID_RETRY_STATUS_FILTERS = %w[pending retried skipped retry_failed].freeze

  def show
    @retry_status_filter = params[:retry_status].presence
    @retry_status_filter = nil unless VALID_RETRY_STATUS_FILTERS.include?(@retry_status_filter)

    @failures = @execution.failures
      .includes(:customer, :recap_movie, :retried_by)
      .order(failed_at: :desc)
    @failures = @failures.where(retry_status: @retry_status_filter) if @retry_status_filter
  end

  def retry_failures
    if @execution.active?
      redirect_to admin_singing_recap_movie_batch_execution_path(@execution),
                  alert: "このBatch はまだ実行中です。完了後に再実行してください。"
      return
    end

    if SingingRecapMovieBatchExecution.active_for_year(@execution.year)
                                      .where.not(id: @execution.id).exists?
      redirect_to admin_singing_recap_movie_batch_execution_path(@execution),
                  alert: "#{@execution.year}年の Batch が別途実行中のため再実行できません。"
      return
    end

    retryable_failures = @execution.failures.retry_pending
    if retryable_failures.empty?
      redirect_to admin_singing_recap_movie_batch_execution_path(@execution),
                  alert: "再実行対象の failure がありません。"
      return
    end

    success_count = 0
    skip_count    = 0
    fail_count    = 0

    retryable_failures.each do |failure|
      result = Singing::RecapMovieFailureRetryService.call(
        failure: failure,
        admin:   current_admin
      )
      if result.success?
        success_count += 1
      elsif failure.reload.retry_skipped?
        skip_count += 1
      else
        fail_count += 1
      end
    end

    parts = []
    parts << "#{success_count}件を再実行予約しました" if success_count > 0
    parts << "#{skip_count}件はスキップされました（完了済みのため）" if skip_count > 0
    parts << "#{fail_count}件のRetryが失敗しました" if fail_count > 0
    message = parts.join("、")

    redirect_to admin_singing_recap_movie_batch_execution_path(@execution), notice: message
  end

  private

  def set_execution
    @execution = SingingRecapMovieBatchExecution
      .includes(:admin, failures: :customer)
      .find(params[:id])
  end
end
