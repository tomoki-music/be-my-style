# Singing Share Image Cleanup Scheduler

BeMyStyle Singing の公開シェア画像は一時 URL として運用する。期限切れ画像、古い failed レコード、添付欠損レコード、古い orphan blob は `Singing::CleanupExpiredShareImagesJob` で削除する。

本番 EC2 への cron 登録は人間が手作業で行う。この手順では secret 値、credentials、master.key、`.env` は確認しない。

## 前提

- 本番 Rails app path: `/var/www/be-my-style/current`
- 実行スクリプト: `/var/www/be-my-style/current/bin/cleanup_singing_share_images`
- cron log: `/var/www/be-my-style/current/log/cron_singing_share_images.log`
- Rails log: `/var/www/be-my-style/current/log/production.log`
- デフォルトの bundle path: `$HOME/.rbenv/shims/bundle`

実運用メモ:

- 今回確認した本番 EC2 の実配置は `APP_ROOT=/home/ec2-user/be-my-style`
- 実際に登録した cron は以下

```cron
0 * * * * APP_ROOT=/home/ec2-user/be-my-style /home/ec2-user/be-my-style/bin/cleanup_singing_share_images >> /home/ec2-user/be-my-style/log/cron_singing_share_images.log 2>&1
```

環境差分がある場合は、`APP_ROOT` または `BUNDLE_BIN` で上書きできる。

```bash
APP_ROOT=/var/www/be-my-style/current \
BUNDLE_BIN=$HOME/.rbenv/shims/bundle \
/var/www/be-my-style/current/bin/cleanup_singing_share_images
```

## 1. 登録前の確認

本番 EC2 にログイン後、既存の cron と crond の状態を確認する。

```bash
crontab -l
systemctl status crond
```

`systemctl status crond` が `active (running)` でない場合は、cron が実行されない。起動や再起動は本番サーバー操作のため、必ず事前確認してから行う。

参考確認コマンド:

```bash
systemctl is-active crond
systemctl is-enabled crond
journalctl -u crond -n 100 --no-pager
```

Amazon Linux 系で service 名が異なる場合は、以下も確認する。

```bash
systemctl status cron
systemctl status cronie
```

## 2. 手動実行

cron 登録前に、必ず手動実行で rails runner と job 起動を確認する。

```bash
cd /var/www/be-my-style/current
/var/www/be-my-style/current/bin/cleanup_singing_share_images
```

正常終了時は標準出力に `start` と `finish exit_status=0` が出る。失敗時は `failed exit_status=...` が出て、同じ exit code で終了する。

rails runner を直接確認したい場合は、以下を使う。

```bash
cd /var/www/be-my-style/current
RAILS_ENV=production DISABLE_SPRING=1 ~/.rbenv/shims/bundle exec rails runner 'Singing::CleanupExpiredShareImagesJob.perform_now'
```

## 3. cron 登録

既存設定を壊さないように、まず現在の crontab を表示して内容を確認する。

```bash
crontab -l
```

次の行を追加する。1 時間に 1 回、毎時 0 分に cleanup を実行し、stdout/stderr を cron log に追記する。

```cron
0 * * * * /var/www/be-my-style/current/bin/cleanup_singing_share_images >> /var/www/be-my-style/current/log/cron_singing_share_images.log 2>&1
```

登録前に確認すること:

- `/var/www/be-my-style/current` が本番 Rails app の current path と一致している
- cron を登録するユーザーが Rails app を実行できるユーザーである
- `$HOME/.rbenv/shims/bundle` がそのユーザーで存在する
- `log/cron_singing_share_images.log` に追記できる
- 同じ job を実行する cron が重複登録されていない

cron 反映と本番サーバー操作は、必ず事前にユーザー確認してから行う。

## 4. ログ確認

cron の起動結果は cron log を確認する。

```bash
tail -n 100 /var/www/be-my-style/current/log/cron_singing_share_images.log
```

期待するログ例:

```text
[2026-05-15 00:00:00 +0900] cleanup_singing_share_images start app_root=/var/www/be-my-style/current bundle_bin=/home/deploy/.rbenv/shims/bundle
[2026-05-15 00:00:10 +0900] cleanup_singing_share_images finish exit_status=0
```

削除件数など job の詳細は Rails production log を確認する。

```bash
grep CleanupExpiredShareImagesJob /var/www/be-my-style/current/log/production.log
tail -n 200 /var/www/be-my-style/current/log/production.log
```

job は開始・終了時に Rails logger へ以下を出す。

- `target_count`: cleanup 対象レコード数
- `purge_success_count`: 添付画像 purge 成功数
- `destroy_count`: `SingingShareImage` 削除数
- `orphan_blob_purge_count`: share image 配下の orphan blob 削除数
- `error_count`: レコードまたは blob 単位の失敗数

エラー時は secret や customer 情報を出さず、`share_image_id` または `blob_id` と error class/message のみを出す。

cron log は増え続けるため、既存 EC2 の logrotate 運用に合わせて `log/cron_singing_share_images.log` をローテーション対象にする。logrotate を変更する場合も本番サーバー操作として事前確認してから行う。

## 5. トラブルシュート

### cron log が増えない

crond が動いているか確認する。

```bash
systemctl status crond
systemctl is-active crond
journalctl -u crond -n 100 --no-pager
```

crontab が登録されているか確認する。

```bash
crontab -l
```

実行ユーザーや path が正しいか確認する。

```bash
whoami
ls -l /var/www/be-my-style/current/bin/cleanup_singing_share_images
ls -ld /var/www/be-my-style/current/log
```

### `bundle: command not found` または Ruby path エラー

cron はログインシェルより環境変数が少ない。`BUNDLE_BIN` を明示して手動実行し、成功する path を確認する。

```bash
BUNDLE_BIN=$HOME/.rbenv/shims/bundle /var/www/be-my-style/current/bin/cleanup_singing_share_images
```

cron 行へ環境差分を入れる場合は、既存 EC2 の Ruby 運用に合わせてから登録する。

### Rails runner が失敗する

cron log の `failed exit_status=...` と Rails production log を確認する。

```bash
tail -n 100 /var/www/be-my-style/current/log/cron_singing_share_images.log
grep CleanupExpiredShareImagesJob /var/www/be-my-style/current/log/production.log
```

原因特定前に本番設定変更、再起動、データ修正はしない。

### permission denied が出る

実行権限と log 書き込み権限を確認する。

```bash
ls -l /var/www/be-my-style/current/bin/cleanup_singing_share_images
ls -ld /var/www/be-my-style/current/log
```

権限変更が必要な場合は本番サーバー操作のため、事前確認してから行う。

### cleanup 対象が多すぎる、または削除されない

Rails production log の `target_count`、`destroy_count`、`orphan_blob_purge_count`、`error_count` を確認する。必要なら read-only の Rails console / runner で対象件数だけ確認し、原因特定前にデータ修正や job 再実行を繰り返さない。

## OGP crawler check

公開 URL は `noindex,nofollow` を出す。X / LINE / Facebook / Discord の検証時は、公開 URL に `?debug_ogp=1` を付けるとページ内で `og:title`、`og:description`、`og:image`、`robots` を確認できる。

SNS 側の OGP cache は各サービスの仕様に依存するため、画像を再生成した場合は新しい signed URL で確認する。
