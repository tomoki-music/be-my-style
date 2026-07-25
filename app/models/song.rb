class Song < ApplicationRecord
  belongs_to :event, inverse_of: :songs
  has_many :song_customers, dependent: :destroy
  has_many :customers, through: :song_customers, dependent: :destroy
  has_many :join_parts, dependent: :destroy

  accepts_nested_attributes_for :join_parts, allow_destroy: true, reject_if: :all_blank
  
  with_options presence: true do
    validates :song_name
  end

  validates :performance_time,
            format: {
              with: /\A\d{1,2}:\d{2}\z/,
              message: "は MM:SS 形式で入力してください"
            },
            allow_blank: true
  validates :performance_start_time,
            format: {
              with: /\A\d{1,2}:\d{2}\z/,
              message: "は HH:MM 形式で入力してください"
            },
            allow_blank: true

  before_validation :set_default_position, on: :create

  # 参加者が0人のパートを「募集中」とみなす。Public::EventsController#showの
  # 成立楽曲/募集中楽曲判定(join_parts.map { customers.length }.include?(0))と
  # 同じ基準に統一する(曲カード側で独自の募集判定基準を新設しない)。
  def recruiting_join_parts
    join_parts.select { |join_part| join_part.customers.empty? }
  end

  private
  
  def set_default_position
    self.position ||= (event.songs.maximum(:position) || 0) + 1 if event.present?
  end

end
