# Business のコミュニティ・プロジェクトの「招待用URL」(共有リンク)を組み立てるときのホスト。
# リクエストの Host ヘッダーは偽装できるため使わず、本番は HTTPS の正規ホストに固定する(メール本文のURLと同じホスト)。
Rails.application.config.x.business_share_url_options =
  if Rails.env.production?
    { protocol: "https", host: "be-my-style.com", port: nil }
  else
    { protocol: "http", host: "localhost", port: 3000 }
  end.freeze
