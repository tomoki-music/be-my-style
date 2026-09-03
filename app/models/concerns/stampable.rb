module Stampable
  extend ActiveSupport::Concern

  # 運営があらかじめ用意したプリセットのイラストスタンプ。
  # key   … DB(stamp_type カラム)へ保存する変更されにくい識別子。
  # label … 画面表示・代替テキストに使う日本語名。
  # asset … app/assets/images 配下の SVG パス。image_tag / asset_path で解決する。
  #
  # スタンプの表示名・画像パスは必ずこの定義から解決し、ユーザー入力(パラメータ)由来の
  # 文字列を画像パスや HTML として扱わない。保存できるのは下記 key と LEGACY_STAMP_LABELS
  # の key のみ(VALID_STAMP_TYPES)。
  STAMP_DEFINITIONS = {
    "like"        => { label: "いいね",       asset: "stamps/stamp_like.svg" },
    "thanks"      => { label: "ありがとう",   asset: "stamps/stamp_thanks.svg" },
    "good_job"    => { label: "お疲れ様",     asset: "stamps/stamp_good_job.svg" },
    "ok"          => { label: "OK",           asset: "stamps/stamp_ok.svg" },
    "wonderful"   => { label: "素敵",         asset: "stamps/stamp_wonderful.svg" },
    "see_you"     => { label: "また！",       asset: "stamps/stamp_see_you.svg" },
    "please"      => { label: "お願いします", asset: "stamps/stamp_please.svg" },
    "huh"         => { label: "あれ？",       asset: "stamps/stamp_huh.svg" },
    "recommend"   => { label: "おすすめ",     asset: "stamps/stamp_recommend.svg" },
    "doing_great" => { label: "快調です",     asset: "stamps/stamp_doing_great.svg" }
  }.freeze

  # イラストスタンプ導入前から使われている絵文字スタンプ。既存レコードの表示と
  # バリデーション互換のために「保存済みの値としては有効」なまま残すが、
  # 新規投稿用のスタンプピッカーには表示しない。
  LEGACY_STAMP_LABELS = {
    "clap"   => "👏 ナイス！",
    "fire"   => "🔥 アツい！",
    "music"  => "🎵 参加したい！",
    "thanks" => "🙏 ありがとう！",
    "love"   => "😍 最高！"
  }.freeze

  # stamp_type に保存を許可する全キー(新イラスト + レガシー絵文字)。
  VALID_STAMP_TYPES = (STAMP_DEFINITIONS.keys | LEGACY_STAMP_LABELS.keys).freeze

  included do
    validates :stamp_type,
              inclusion: { in: VALID_STAMP_TYPES, message: "が不正です" },
              allow_blank: true
  end

  def stamped?
    stamp_type.present?
  end

  # プリセットのイラストスタンプ(SVG で表示すべきもの)か。
  # レガシー絵文字キーや未設定の場合は false。
  def illustration_stamp?
    STAMP_DEFINITIONS.key?(stamp_type.to_s)
  end

  # イラストスタンプの定義(label / asset)。イラストスタンプでなければ nil。
  def stamp_definition
    STAMP_DEFINITIONS[stamp_type.to_s]
  end

  # 表示名。新イラスト・レガシー絵文字のどちらのキーでも解決する。
  def stamp_label
    stamp_definition&.fetch(:label) || LEGACY_STAMP_LABELS[stamp_type.to_s]
  end
end
