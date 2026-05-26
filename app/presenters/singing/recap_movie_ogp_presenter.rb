module Singing
  class RecapMovieOgpPresenter
    # placeholder: replace with a dedicated 1200x630 design asset when available
    IMAGE_ASSET_NAME = "acguitar-girl.jpg".freeze

    def initialize(recap_movie, customer)
      @recap_movie = recap_movie
      @customer    = customer
    end

    def title
      "#{@customer.name}さんの #{@recap_movie.year} Singing Recap | BeMyStyle"
    end

    def description
      "BeMyStyleで記録した#{@recap_movie.year}年の歌声の成長を、Recap Movieとして公開中。"
    end

    def twitter_card
      "summary_large_image"
    end

    def image_asset_name
      IMAGE_ASSET_NAME
    end
  end
end
