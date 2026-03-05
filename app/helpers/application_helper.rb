module ApplicationHelper

  def enum_filter_options(enum_hash, i18n_scope)
    [["全て", ""]] +
      enum_hash.keys.map { |k| [I18n.t("#{i18n_scope}.#{k}"), k] }
  end
  
  def html_safe_newline(str)
    h(str).gsub(/\n|\r|\r\n/, "<br>").html_safe
  end

  module Public::SongsHelper
    def extract_youtube_id(url)
      uri = URI.parse(url)
      if uri.host == 'youtu.be'
        uri.path[1..]
      elsif uri.host&.include?('youtube.com')
        Rack::Utils.parse_nested_query(uri.query)['v']
      end
    rescue
      nil
    end
  end
  
end
