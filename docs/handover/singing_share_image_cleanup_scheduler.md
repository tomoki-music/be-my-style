# Singing Share Image Cleanup Scheduler

BeMyStyle Singing の公開シェア画像は一時 URL として運用する。期限切れ画像、古い failed レコード、添付欠損レコード、古い orphan blob は `Singing::CleanupExpiredShareImagesJob` で削除する。

## Production cron

既存 EC2 の cron 運用に合わせ、production では rails runner を 1 時間に 1 回実行する。

```cron
0 * * * * cd /path/to/app && RAILS_ENV=production DISABLE_SPRING=1 ~/.rbenv/shims/bundle exec rails runner 'Singing::CleanupExpiredShareImagesJob.perform_now'
```

設定時は `/path/to/app` を本番 Rails app の current path に置き換える。cron 反映と本番サーバー操作は、必ず事前にユーザー確認してから行う。

## Logging

job は開始・終了時に Rails logger へ以下を出す。

- `target_count`: cleanup 対象レコード数
- `purge_success_count`: 添付画像 purge 成功数
- `destroy_count`: `SingingShareImage` 削除数
- `orphan_blob_purge_count`: share image 配下の orphan blob 削除数
- `error_count`: レコードまたは blob 単位の失敗数

エラー時は secret や customer 情報を出さず、`share_image_id` または `blob_id` と error class/message のみを出す。

## OGP crawler check

公開 URL は `noindex,nofollow` を出す。X / LINE / Facebook / Discord の検証時は、公開 URL に `?debug_ogp=1` を付けるとページ内で `og:title`、`og:description`、`og:image`、`robots` を確認できる。

SNS 側の OGP cache は各サービスの仕様に依存するため、画像を再生成した場合は新しい signed URL で確認する。
