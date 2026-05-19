class Singing::RecapMoviesController < Singing::BaseController
  before_action :authenticate_customer!
  before_action :set_recap_movie, only: [:show]

  def index
    @recap_movies = current_customer.singing_generated_recap_movies.order(year: :desc)
  end

  def show
  end

  private

  def set_recap_movie
    @recap_movie = current_customer.singing_generated_recap_movies.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to singing_recap_movies_path, alert: "Recap Movieが見つかりません。"
  end
end
