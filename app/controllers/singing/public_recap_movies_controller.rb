class Singing::PublicRecapMoviesController < Singing::BaseController
  skip_before_action :authenticate_customer!, only: [:show]
  skip_before_action :ensure_singing_access!,  only: [:show]

  def show
    @recap_movie = SingingGeneratedRecapMovie
      .joins(:customer)
      .find_by(share_token: params[:share_token])

    # 退会した会員の動画は、ファイルの削除が済む前・削除に失敗した場合も公開しない。
    unless @recap_movie&.share_publicly_accessible? && !@recap_movie.customer.is_deleted?
      render :not_found, status: :not_found
      return
    end

    @customer = @recap_movie.customer
  end
end
