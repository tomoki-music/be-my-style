class CustomerSongPart < ApplicationRecord
  belongs_to :customer
  belongs_to :song_master
  belongs_to :song, optional: true

  # song(具体的なイベント由来のSong行)は常にoptional。
  # 既存Songを選んで登録する場合はsongを設定するが、曲名・アーティスト名の自由入力
  # (イベントに存在しない曲)で登録する場合はsongを持たず、song_masterのみを参照する。
  # そのため「新規作成時は必須」という制約は設けない(以前はここでvalidates :song, presence: true, on: :createと
  # していたが、自由入力登録を導入したため撤廃した)。
  validates :part_name, presence: true, inclusion: { in: JoinPart::NAME_OPTIONS }
  validates :customer_id, uniqueness: {
    scope: [:song_master_id, :part_name],
    message: "は既に演奏可能曲として登録されています"
  }
end
