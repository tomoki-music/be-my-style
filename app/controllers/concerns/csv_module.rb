module CsvModule
  extend ActiveSupport::Concern
  require 'csv'

  CSV_PART_HEADERS = ["Vocal", "Guitar", "Bass", "Drums", "Keyboard"].freeze

  def generate_csv(event)
    filename = "参加メンバー一覧_#{Date.today}.csv"
    set_csv_request_headers(filename)

    bom = "\uFEFF"
    self.response_body = Enumerator.new do |csv_data|
      csv_data << bom

      header = ["曲順", "演奏時間", "曲名", *CSV_PART_HEADERS]
      csv_data << header.to_csv

      event.songs.each_with_index do |song, index|
        body = [
          song.position.presence || index + 1,
          song.performance_time.to_s,
          song.song_name,
          *CSV_PART_HEADERS.map { |part_name| csv_part_members(song, part_name, event) }
        ]
        csv_data << body.to_csv
      end
    end
  end

  def set_csv_request_headers(filename, charset: 'UTF-8')
    self.response.headers['Content-Type'] ||= "text/csv; charset=#{charset}"
    self.response.headers['Content-Disposition'] = "attachment;filename=#{ERB::Util.url_encode(filename)}"
    self.response.headers['Content-Transfer-Encoding'] = 'binary'
  end

  private

  def csv_part_members(song, part_name, event)
    join_part = song.join_parts.find { |part| part.join_part_name == part_name }
    return "" unless join_part

    join_part.customers.map { |customer| decorate_customer_name(customer, event) }.join(" / ")
  end

  def decorate_customer_name(customer, event)
    badges = []
    badges << "有料" if event.paid_participant_for_display?(customer)
    badges << "特典適用" if event.session_credit_applied_for?(customer)
    if event.session_credit_applied_for?(customer) && event.participant_remaining_fee_for(customer).zero?
      badges << "集金不要"
    end

    badges.any? ? "#{customer.name}(#{badges.join('/')})" : customer.name
  end
end
