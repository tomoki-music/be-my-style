module Business
  # 利用イメージの絵(青いリボンが交わり、オンラインでつながる様子)。原本は docs/business_social_atelier/illustrations/。
  # 縦横比(3:2)を保ったまま縮小した2サイズを使い分け、表示サイズを必ず指定してレイアウトのずれを防ぐ。
  # 説明は HTML 側に書くため、画像は装飾扱い(alt 空)。
  module IllustrationHelper
    ILLUSTRATIONS = {
      ribbon: { file: "ribbon.webp", width: 1200, height: 800 },
      ribbon_small: { file: "ribbon-small.webp", width: 480, height: 320 }
    }.freeze

    def business_illustration(name, class_name: nil, loading: "lazy")
      illustration = ILLUSTRATIONS.fetch(name)
      image_tag "business/illustrations/#{illustration[:file]}",
        alt: "", width: illustration[:width], height: illustration[:height], loading: loading, decoding: "async",
        class: ["ba-illust", class_name]
    end
  end
end
