class Singing::PublicRecapMoviesController < Singing::BaseController
  skip_before_action :authenticate_customer!, only: [:show]
  skip_before_action :ensure_singing_access!,  only: [:show]

  def show
    @recap_movie = SingingGeneratedRecapMovie
      .joins(:customer)
      .find_by(share_token: params[:share_token])

    unless @recap_movie&.shareable?
      render :not_found, status: :not_found
      return
    end

    @customer = @recap_movie.customer
  end
end
