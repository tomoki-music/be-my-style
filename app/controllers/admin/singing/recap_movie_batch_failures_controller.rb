class Admin::Singing::RecapMovieBatchFailuresController < ApplicationController
  skip_before_action :authenticate_customer!
  skip_before_action :ensure_music_domain_access_for_public_routes!, raise: false
  before_action :authenticate_admin!
  before_action :set_failure

  def retry
    result = Singing::RecapMovieFailureRetryService.call(
      failure: @failure,
      admin:   current_admin
    )

    if result.success?
      redirect_to admin_singing_recap_movie_batch_execution_path(@failure.singing_recap_movie_batch_execution),
                  notice: result.message
    else
      redirect_to admin_singing_recap_movie_batch_execution_path(@failure.singing_recap_movie_batch_execution),
                  alert: result.message
    end
  end

  private

  def set_failure
    @failure = SingingRecapMovieBatchFailure
      .includes(:singing_recap_movie_batch_execution, :customer, :recap_movie)
      .find(params[:id])
  end
end
