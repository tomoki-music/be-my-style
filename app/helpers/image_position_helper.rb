module ImagePositionHelper
  # 編集画面のプレビューに並べる「実際の表示枠」。縦横比は各画面の CSS の実寸に合わせる。
  # width はプレビュー内での大きさ(見比べやすさのため)で、実寸とは一致しなくてよい。
  IMAGE_POSITION_FRAMES = {
    business_community: [
      { label: "詳細画面のカバー（PC）", ratio: "990 / 120", width: "100%" },
      { label: "詳細画面のカバー（スマホ）", ratio: "343 / 120", width: "min(100%, 343px)" },
      { label: "アイコン（詳細・一覧・ホーム）", ratio: "1 / 1", width: "72px", shape: "circle" }
    ],
    business_project: [
      { label: "詳細画面のカバー", ratio: "16 / 7", width: "min(100%, 400px)" },
      { label: "一覧カード（PC）", ratio: "16 / 10", width: "200px" },
      { label: "一覧カード（スマホ）", ratio: "1 / 1", width: "104px" }
    ],
    business_profile: [
      { label: "プロフィール", ratio: "1 / 1", width: "120px", shape: "circle" },
      { label: "アイコン", ratio: "1 / 1", width: "56px", shape: "circle" }
    ],
    music_community: [
      { label: "一覧（PC）", ratio: "255 / 300", width: "150px", shape: "rounded" },
      { label: "詳細（PC）", ratio: "218 / 300", width: "128px", shape: "rounded" },
      { label: "一覧・詳細（スマホ）", ratio: "1 / 1", width: "176px", shape: "rounded" },
      { label: "チャット", ratio: "1 / 1", width: "56px", shape: "rounded" }
    ],
    music_profile: [
      { label: "一覧（PC）", ratio: "255 / 300", width: "150px", shape: "rounded" },
      { label: "詳細（PC）", ratio: "218 / 300", width: "128px", shape: "rounded" },
      { label: "一覧・詳細（スマホ）", ratio: "1 / 1", width: "176px", shape: "rounded" },
      { label: "アイコン", ratio: "1 / 1", width: "56px", shape: "circle" }
    ]
  }.freeze

  # 保存済みの表示位置を object-position の style にする。未調整なら nil(既存の見え方のまま)。
  def image_position_style(record, attachment_name)
    position = record.try("#{attachment_name}_object_position")
    "object-position: #{position};" if position.present?
  end

  # 位置付きで画像を出す。表示枠の CSS 側に object-fit: cover があることが前提。
  def positioned_image_tag(record, attachment_name, **options)
    style = [options.delete(:style), image_position_style(record, attachment_name)].compact.join(" ").presence
    image_tag record.public_send(attachment_name), **options, style: style
  end

  def image_position_frames(preset)
    IMAGE_POSITION_FRAMES.fetch(preset.to_sym)
  end

  # 編集画面に出す保存済み画像。バリデーションで差し戻された未保存の画像は URL を作れないので出さない。
  def image_position_saved_url(record, attachment_name)
    attachment = record.public_send(attachment_name)
    return unless attachment.attached?
    return if record.attachment_changes.key?(attachment_name.to_s)
    return unless attachment.blob&.persisted?

    url_for(attachment)
  end
end
