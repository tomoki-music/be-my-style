class SongTemplate < ApplicationRecord
  belongs_to :community
  belongs_to :customer, optional: true
  belongs_to :source_song, class_name: "Song", optional: true, inverse_of: :song_templates

  validates :song_name, presence: true

  validates :chord_sheet_url,
            length: { maximum: 2048 },
            allow_blank: true
  validates :tab_sheet_url,
            length: { maximum: 2048 },
            allow_blank: true
  validates :musical_key,
            length: { maximum: 100 },
            allow_blank: true
  validates :capo,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: 12
            },
            allow_nil: true
  validates :chord_sheet_note,
            length: { maximum: 300 },
            allow_blank: true

  # イベントフォームのSong新規行へJS側でコピーするための属性一覧。
  # event_id/position/performance_time等のイベント固有情報は含めない。
  def copyable_attributes
    {
      song_name: song_name,
      artist_name: artist_name,
      youtube_url: youtube_url,
      introduction: introduction,
      chord_sheet_url: chord_sheet_url,
      tab_sheet_url: tab_sheet_url,
      musical_key: musical_key,
      capo: capo,
      chord_sheet_note: chord_sheet_note
    }
  end
end
