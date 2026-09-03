module Stampable
  extend ActiveSupport::Concern

  # 運営があらかじめ用意したプリセットのイラストスタンプ。
  # key      … DB(stamp_type カラム)へ保存する変更されにくい識別子。
  # label    … 画面表示・代替テキストに使う日本語名。
  # asset    … app/assets/images 配下の画像パス。image_tag / asset_path で解決する。
  # category … ピッカーのタブ分類(:simple = 既存SVG / :human = 人物PNG / :animal = どうぶつPNG)。
  #
  # スタンプの表示名・画像パスは必ずこの定義から解決し、ユーザー入力(パラメータ)由来の
  # 文字列を画像パスや HTML として扱わない。保存できるのは下記 key と LEGACY_STAMP_LABELS
  # の key のみ(VALID_STAMP_TYPES)。
  STAMP_DEFINITIONS = {
    # シンプル(導入時からのSVGイラスト 10種)
    "like"        => { label: "いいね",       asset: "stamps/stamp_like.svg",        category: :simple },
    "thanks"      => { label: "ありがとう",   asset: "stamps/stamp_thanks.svg",      category: :simple },
    "good_job"    => { label: "お疲れ様",     asset: "stamps/stamp_good_job.svg",    category: :simple },
    "ok"          => { label: "OK",           asset: "stamps/stamp_ok.svg",          category: :simple },
    "wonderful"   => { label: "素敵",         asset: "stamps/stamp_wonderful.svg",   category: :simple },
    "see_you"     => { label: "また！",       asset: "stamps/stamp_see_you.svg",     category: :simple },
    "please"      => { label: "お願いします", asset: "stamps/stamp_please.svg",      category: :simple },
    "huh"         => { label: "あれ？",       asset: "stamps/stamp_huh.svg",         category: :simple },
    "recommend"   => { label: "おすすめ",     asset: "stamps/stamp_recommend.svg",   category: :simple },
    "doing_great" => { label: "快調です",     asset: "stamps/stamp_doing_great.svg", category: :simple },

    # 人物(PNGイラスト 10種)
    "character_like"        => { label: "いいね",       asset: "stamps/stamp_character_like.png",        category: :human },
    "character_thanks"      => { label: "ありがとう",   asset: "stamps/stamp_character_thanks.png",      category: :human },
    "character_good_job"    => { label: "お疲れ様",     asset: "stamps/stamp_character_good_job.png",    category: :human },
    "character_ok"          => { label: "OK",           asset: "stamps/stamp_character_ok.png",          category: :human },
    "character_wonderful"   => { label: "素敵",         asset: "stamps/stamp_character_wonderful.png",   category: :human },
    "character_see_you"     => { label: "また！",       asset: "stamps/stamp_character_see_you.png",     category: :human },
    "character_please"      => { label: "お願いします", asset: "stamps/stamp_character_please.png",      category: :human },
    "character_huh"         => { label: "あれ？",       asset: "stamps/stamp_character_huh.png",         category: :human },
    "character_recommend"   => { label: "おすすめ",     asset: "stamps/stamp_character_recommend.png",   category: :human },
    "character_doing_great" => { label: "快調です",     asset: "stamps/stamp_character_doing_great.png", category: :human },

    # どうぶつ(PNGイラスト 6種)
    "animal_got_it"     => { label: "了解！",       asset: "stamps/stamp_animal_got_it.png",     category: :animal },
    "animal_best"       => { label: "最高！",       asset: "stamps/stamp_animal_best.png",       category: :animal },
    "animal_yay"        => { label: "わーい！",     asset: "stamps/stamp_animal_yay.png",        category: :animal },
    "animal_lets_do_it" => { label: "がんばろう！", asset: "stamps/stamp_animal_lets_do_it.png", category: :animal },
    "animal_excited"    => { label: "楽しみ！",     asset: "stamps/stamp_animal_excited.png",    category: :animal },
    "animal_sorry"      => { label: "ごめんなさい", asset: "stamps/stamp_animal_sorry.png",      category: :animal }
  }.freeze

  # ピッカーのタブ順(先頭が初期表示)と表示名。
  STAMP_CATEGORY_LABELS = {
    simple: "シンプル",
    human:  "人物",
    animal: "どうぶつ"
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

  # { category => { key => definition } }。タブ順を保ったカテゴリ別の定義一覧。
  def self.definitions_by_category
    STAMP_CATEGORY_LABELS.keys.index_with do |category|
      STAMP_DEFINITIONS.select { |_key, definition| definition[:category] == category }
    end
  end

  included do
    validates :stamp_type,
              inclusion: { in: VALID_STAMP_TYPES, message: "が不正です" },
              allow_blank: true
  end

  def stamped?
    stamp_type.present?
  end

  # プリセットのイラストスタンプ(画像で表示すべきもの)か。
  # レガシー絵文字キーや未設定の場合は false。
  def illustration_stamp?
    STAMP_DEFINITIONS.key?(stamp_type.to_s)
  end

  # イラストスタンプの定義(label / asset / category)。イラストスタンプでなければ nil。
  def stamp_definition
    STAMP_DEFINITIONS[stamp_type.to_s]
  end

  # 表示名。新イラスト・レガシー絵文字のどちらのキーでも解決する。
  def stamp_label
    stamp_definition&.fetch(:label) || LEGACY_STAMP_LABELS[stamp_type.to_s]
  end
end
