# Singing Share Image Cleanup Scheduler

BeMyStyle Singing の公開シェア画像は一時 URL として運用する。期限切れ画像、古い failed レコード、添付欠損レコード、古い orphan blob は `Singing::CleanupExpiredShareImagesJob` で削除する。

## Production cron

既存 EC2 の cron 運用に合わせ、production では rails runner を 1 時間に 1 回実行する。いきなり cron を変更せず、まず現在の設定を確認する。

```bash
crontab -l
```

runner script は `bin/cleanup_singing_share_images` を使う。デフォルトの本番 app path は `/var/www/be-my-style/current`。環境差分がある場合は `APP_ROOT` または `BUNDLE_BIN` で上書きできる。

```bash
APP_ROOT=/var/www/be-my-style/current \
BUNDLE_BIN=$HOME/.rbenv/shims/bundle \
/var/www/be-my-style/current/bin/cleanup_singing_share_images
```

cron 登録例:

```cron
0 * * * * /var/www/be-my-style/current/bin/cleanup_singing_share_images >> /var/www/be-my-style/current/log/cron_singing_share_images.log 2>&1
```

cron 反映と本番サーバー操作は、必ず事前にユーザー確認してから行う。登録前に上記 cron 行をレビューし、本番 Rails app の current path、実行ユーザー、Ruby/bundle path が既存 EC2 の運用と一致することを確認する。

## Logging

cron stdout/stderr は以下に追記する。

```text
/var/www/be-my-style/current/log/cron_singing_share_images.log
```

job は開始・終了時に Rails logger へ以下を出す。

- `target_count`: cleanup 対象レコード数
- `purge_success_count`: 添付画像 purge 成功数
- `destroy_count`: `SingingShareImage` 削除数
- `orphan_blob_purge_count`: share image 配下の orphan blob 削除数
- `error_count`: レコードまたは blob 単位の失敗数

エラー時は secret や customer 情報を出さず、`share_image_id` または `blob_id` と error class/message のみを出す。

cron log は増え続けるため、既存 EC2 の logrotate 運用に合わせて `log/cron_singing_share_images.log` をローテーション対象にする。logrotate を変更する場合も本番サーバー操作として事前確認してから行う。

## Smoke test

cron 登録前に、本番 EC2 上で手動実行して rails runner と job 起動を確認する。

```bash
cd /var/www/be-my-style/current
RAILS_ENV=production DISABLE_SPRING=1 ~/.rbenv/shims/bundle exec rails runner 'Singing::CleanupExpiredShareImagesJob.perform_now'
```

runner script 経由でも確認する。

```bash
/var/www/be-my-style/current/bin/cleanup_singing_share_images
```

実行後は cron log と Rails production log を確認する。

```bash
tail -n 100 /var/www/be-my-style/current/log/cron_singing_share_images.log
grep CleanupExpiredShareImagesJob /var/www/be-my-style/current/log/production.log
```

## OGP crawler check

公開 URL は `noindex,nofollow` を出す。X / LINE / Facebook / Discord の検証時は、公開 URL に `?debug_ogp=1` を付けるとページ内で `og:title`、`og:description`、`og:image`、`robots` を確認できる。

SNS 側の OGP cache は各サービスの仕様に依存するため、画像を再生成した場合は新しい signed URL で確認する。
