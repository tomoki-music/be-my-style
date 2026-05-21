class Admin::Singing::RecapMovieBatchExecutionsController < ApplicationController
  skip_before_action :authenticate_customer!
  skip_before_action :ensure_music_domain_access_for_public_routes!, raise: false
  before_action :authenticate_admin!

  def show
    @execution = SingingRecapMovieBatchExecution
      .includes(:admin, failures: :customer)
      .find(params[:id])
    @failures = @execution.failures
      .includes(:customer, :recap_movie)
      .order(failed_at: :desc)
  end
end
