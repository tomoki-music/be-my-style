class Singing::MemoryAlbumsController < Singing::BaseController
  before_action :authenticate_customer!

  def show
    album = Singing::MemoryAlbumBuilder.call(current_customer)

    album.items.each do |item|
      item.detail_url = resolve_detail_url(item)
    end

    @album = album
  end

  private

  def resolve_detail_url(item)
    case item.type
    when :year_recap
      year_recap_singing_badges_path(year: item.occurred_at.year)
    when :monthly_wrapped
      monthly_wrapped_singing_badges_path(month: item.occurred_at.strftime("%Y-%m"))
    when :singer_story
      nil
    end
  end
end
