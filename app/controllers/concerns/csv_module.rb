module CsvModule
  extend ActiveSupport::Concern
  require 'csv'

  def generate_csv(songs)
    filename = "参加メンバー一覧_#{Date.today}.csv"
    set_csv_request_headers(filename)

    bom = "\uFEFF"
    self.response_body = Enumerator.new do |csv_data|
      csv_data << bom

      header = %i(曲順 名前 内容)
      csv_data << header.to_csv

      number = 1
      songs.each do |song|
        body = [
          number,
          song.song_name,
        ]
        csv_data << body.to_csv
        number += 1
      end
    end
  end

  def set_csv_request_headers(filename, charset: 'UTF-8')
    self.response.headers['Content-Type'] ||= "text/csv; charset=#{charset}"
    self.response.headers['Content-Disposition'] = "attachment;filename=#{ERB::Util.url_encode(filename)}"
    self.response.headers['Content-Transfer-Encoding'] = 'binary'
  end
end