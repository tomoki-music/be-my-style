module CsvModule
  extend ActiveSupport::Concern
  require 'csv'

  def generate_csv(songs)
    filename = "参加メンバー一覧_#{Date.today}.csv"
    set_csv_request_headers(filename)

    bom = "\uFEFF"
    self.response_body = Enumerator.new do |csv_data|
      csv_data << bom

      header = %i(曲順 演奏時間 曲名 内容)
      csv_data << header.to_csv

      number = 1
      songs.each do |song|
        body = [
          number,
          "00:00",
          song.song_name,
          customer_name = [],
          song.join_parts.each do |part|
            part.customers.each do |customer|
              customer_name << customer.name
            end
          end
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