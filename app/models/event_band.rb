# イベントのバンド出演枠。バンド名とパートごとの固定担当者(EventBandMember)を持ち、
# 同じバンドで演奏する複数の曲(Song#event_band_id)に同じメンバーを使い回す。
# バンド出演曲は一般の演奏エントリーとエントリー依頼の対象から外し、「応援する📣」だけを受け付ける。
class EventBand < ApplicationRecord
  NAME_MAX_LENGTH = 100
  SONG_ID_FORMAT = /\A[1-9]\d*\z/

  belongs_to :event, inverse_of: :event_bands
  # 担当者のエラーは members_must_be_valid でバンド側の base に載せる(既定の「Members base …」表示を避ける)。
  has_many :members, -> { order(:id) }, class_name: "EventBandMember", inverse_of: :event_band,
                                         dependent: :destroy, autosave: true, validate: false
  has_many :songs, -> { order(position: :asc) }, inverse_of: :event_band, dependent: :nullify
  has_many :cheers, class_name: "EventBandCheer", inverse_of: :event_band, dependent: :destroy

  validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }
  validate :members_must_be_valid
  validate :selected_songs_must_be_assignable

  after_save :sync_songs

  # パートの並び(JoinPart::NAME_OPTIONS)で、担当者のいるパートだけを返す。
  def ordered_members
    by_part = members.reject(&:marked_for_destruction?).index_by(&:part_name)
    JoinPart::NAME_OPTIONS.filter_map { |part_name| by_part[part_name] }
  end

  # 応援している現役会員。cheers: :customer をpreload済みなら追加クエリを発生させない。
  def active_cheer_customers
    cheers.map(&:customer).compact.reject(&:is_deleted)
  end

  def cheered_by?(customer)
    return false if customer.blank?

    cheers.any? { |cheer| cheer.customer_id == customer.id }
  end

  def member_for(part_name)
    members.detect { |member| member.part_name == part_name }
  end

  # フォームの { "Vocal" => { customer_id:, display_name: }, ... } を反映する。
  # 会員も表示名も空のパートは担当なしとして削除する。会員を選んだパートの表示名は使わないので空にする。
  def assign_part_members(attributes)
    attributes = (attributes || {}).to_h.stringify_keys
    JoinPart::NAME_OPTIONS.each do |part_name|
      values = (attributes[part_name] || {}).to_h.stringify_keys
      customer_id = values["customer_id"].to_s.strip.presence
      display_name = values["display_name"].to_s.strip.presence
      member = member_for(part_name)

      if customer_id.nil? && display_name.nil?
        member&.mark_for_destruction
        next
      end

      member ||= members.build(part_name: part_name)
      member.customer_id = customer_id
      member.display_name = customer_id ? nil : display_name
    end
  end

  # フォームの曲チェック欄の選択状態。入力エラーで再表示するときは入力値を優先する。
  def selected_song_ids
    @selected_song_ids || songs.map(&:id)
  end

  # 値を受け取るだけで、反映は検証を通った後(after_save)に行う。
  def selected_song_ids=(values)
    raw_ids = Array(values).map { |value| value.to_s.strip }.reject(&:blank?)
    @selected_song_ids_malformed = raw_ids.any? { |value| !value.match?(SONG_ID_FORMAT) }
    @selected_song_ids = raw_ids.grep(SONG_ID_FORMAT).map(&:to_i).uniq
  end

  private

  def members_must_be_valid
    members.reject(&:marked_for_destruction?).each do |member|
      next if member.valid?

      member.errors.full_messages.each { |message| errors.add(:base, message) }
    end
  end

  # 既存の演奏エントリーがある曲は、申込みを消さずに済むよう切り替えを止めて理由を伝える。
  def selected_songs_must_be_assignable
    return if @selected_song_ids.nil?

    if @selected_song_ids_malformed
      errors.add(:base, "曲の指定が正しくありません")
      return
    end

    selected_songs = Song.where(event_id: event_id, id: @selected_song_ids).to_a
    if selected_songs.size != @selected_song_ids.size
      errors.add(:base, "このイベントにない曲が含まれています")
      return
    end

    current_ids = persisted? ? Song.where(event_band_id: id).pluck(:id) : []
    added_songs = selected_songs.reject { |song| current_ids.include?(song.id) }
    entered_song_ids = JoinPartCustomer.joins(:join_part).where(join_parts: { song_id: added_songs.map(&:id) })
                                       .distinct.pluck("join_parts.song_id")

    added_songs.each do |song|
      if song.event_band_id.present?
        errors.add(:base, "「#{song.song_name}」は別のバンドの出演曲です。先にそのバンドから外してください")
      elsif entered_song_ids.include?(song.id)
        errors.add(:base, "「#{song.song_name}」には演奏エントリーがあるため、バンド出演曲に切り替えられません。" \
                          "申込みは自動で削除しないので、エントリーが取り消されてから切り替えてください")
      end
    end
  end

  def sync_songs
    return if @selected_song_ids.nil?

    now = Time.current
    Song.where(event_band_id: id).where.not(id: @selected_song_ids).update_all(event_band_id: nil, updated_at: now)
    Song.where(event_id: event_id, id: @selected_song_ids).where(event_band_id: nil)
        .update_all(event_band_id: id, updated_at: now)

    @selected_song_ids = nil
    association(:songs).reset
  end
end
