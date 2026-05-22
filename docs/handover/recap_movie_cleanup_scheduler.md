# Recap Movie Cleanup Scheduler

## 目的

`SingingGeneratedRecapMovie` の `expires_at` を過ぎたレコードを定期クリーンアップする。
ステータスが `pending / processing / completed / failed` かつ `expires_at < 現在時刻` のレコードを対象に `expire!` を呼び出し、S3 動画ファイルの削除とステータスの `expired` 更新を行う。

## 対象 Job

```
Singing::CleanupGeneratedRecapMoviesJob
```

場所: `app/jobs/singing/cleanup_generated_recap_movies_job.rb`

## runner script の場所

```
bin/cleanup_generated_recap_movies
```

本番 EC2 上のフルパス: `/home/ec2-user/be-my-style/bin/cleanup_generated_recap_movies`

## 手動実行方法

### ローカル開発環境

```bash
cd /path/to/be-my-style
DISABLE_SPRING=1 ~/.rbenv/shims/bundle exec rails runner 'Singing::CleanupGeneratedRecapMoviesJob.perform_now'
```

### 本番 EC2 上（必ず事前にユーザー確認してから行う）

```bash
cd /home/ec2-user/be-my-style
APP_ROOT=/home/ec2-user/be-my-style /home/ec2-user/be-my-style/bin/cleanup_expired_recap_movies
```

正常終了時はログに `start` と `finish exit_status=0` が出る。

rails runner を直接確認したい場合:

```bash
cd /home/ec2-user/be-my-style
RAILS_ENV=production DISABLE_SPRING=1 ~/.rbenv/shims/bundle exec rails runner 'Singing::CleanupGeneratedRecapMoviesJob.perform_now'
```

## cron 登録例

深夜 3 時に 1 日 1 回実行する。

```cron
0 3 * * * APP_ROOT=/home/ec2-user/be-my-style /home/ec2-user/be-my-style/bin/cleanup_expired_recap_movies >> /home/ec2-user/be-my-style/log/cron_recap_movie_cleanup.log 2>&1
```

## 実行頻度

1 日 1 回（深夜 3 時 / `0 3 * * *`）

## ログ出力先

| ログ種別 | パス |
|---------|------|
| cron script ログ | `/home/ec2-user/be-my-style/log/cron_recap_movie_cleanup.log` |
| Rails production ログ | `/home/ec2-user/be-my-style/log/production.log` |

cron ログ確認:

```bash
tail -n 100 /home/ec2-user/be-my-style/log/cron_recap_movie_cleanup.log
```

Rails ログ確認:

```bash
grep RecapMovieCleanup /home/ec2-user/be-my-style/log/production.log
```

期待するログ例:

```text
[2026-05-19 03:00:00 +0900] cleanup_expired_recap_movies start app_root=/home/ec2-user/be-my-style env=production
[2026-05-19 03:00:05 +0900] cleanup_expired_recap_movies finish exit_status=0
```

Rails ログ（job 内部）:

```text
[RecapMovieCleanup] expired movie_id=123 year=2025 customer_id=456
[RecapMovieCleanup] failed movie_id=789: ...
```

## rollback 方法

### cron を止める場合（本番 EC2 上）

```bash
crontab -e  # 該当行を削除して保存
crontab -l  # 削除されたか確認
```

cron 登録・削除は本番サーバー操作のため、必ず事前にユーザー確認してから行う。

### コードをロールバックする場合

```bash
git log --oneline -5
git checkout <commit-hash>
```

DB の `status: expired` に変更されたレコードを元に戻すことはできない（`expire!` は非可逆操作）。
S3 から削除済みの動画は復元できない。ロールバック前に影響範囲を確認する。

## purge_later の注意

`expire!` 内で `video_file.purge_later` を呼ぶ（`status: completed` のレコードのみ）。

`purge_later` は ActiveStorage の非同期削除であり、ジョブキューに `ActiveStorage::PurgeJob` を enqueue する。
実際の S3 削除はキューが処理されるまで行われない。

**注意点:**
- `AsyncAdapter`（開発・テスト）では即時 Puma ワーカー内で実行される
- 本番は `AsyncAdapter`（Redis）のため、Sidekiq や Solid Queue を使用している場合はそちらのキュー処理を確認する
- `purge_later` enqueue 後に Rails が落ちた場合、ジョブが失われて S3 にゴミが残る可能性がある

## ActiveStorage queue の注意

`ActiveStorage::PurgeJob` はデフォルトで `:active_storage_purge` キューを使用する。

本番環境のキュー設定を確認する:

```bash
# 本番サーバー上
RAILS_ENV=production DISABLE_SPRING=1 ~/.rbenv/shims/bundle exec rails runner \
  'puts ActiveJob::Base.queue_adapter.class.name'
```

`AsyncAdapter` の場合: Puma ワーカー内で即時実行される。Puma が落ちると削除されない。
Redis + Solid Queue / Sidekiq の場合: 別プロセスが処理する。キューのバックログを定期的に確認する。

## S3 cleanup 注意

`video_file.purge_later` は ActiveStorage が管理する S3 blob を削除する。

**注意点:**
- S3 の削除は非同期（`purge_later`）のため、`expire!` 直後に S3 にファイルが残っている場合がある
- `SingingGeneratedRecapMovie` レコードの `status` が `expired` に変わっても、S3 blob が削除済みとは限らない
- ActiveStorage の `blob` テーブルと S3 の実態の整合性は `ActiveStorage::PurgeJob` の完了後に保証される
- S3 の Lifecycle ポリシーでの自動削除と競合する場合は、どちらが先に削除するか確認しておく

## 本番適用手順（実施する際）

詳細な本番投入チェックリストは [recap_movie_cleanup_production_checklist.md](recap_movie_cleanup_production_checklist.md) を参照。

1. 本番 EC2 に SSH 接続（事前確認必須）
2. デプロイ済みの `bin/cleanup_expired_recap_movies` が存在することを確認
   ```bash
   ls -l /home/ec2-user/be-my-style/bin/cleanup_expired_recap_movies
   ```
3. 実行権限を確認（`-rwxr-xr-x` であること）
4. 手動実行で動作確認
   ```bash
   APP_ROOT=/home/ec2-user/be-my-style /home/ec2-user/be-my-style/bin/cleanup_expired_recap_movies
   ```
5. cron 登録
   ```bash
   crontab -e
   ```
   追加する行:
   ```cron
   0 3 * * * APP_ROOT=/home/ec2-user/be-my-style /home/ec2-user/be-my-style/bin/cleanup_expired_recap_movies >> /home/ec2-user/be-my-style/log/cron_recap_movie_cleanup.log 2>&1
   ```
6. 登録確認
   ```bash
   crontab -l
   ```
7. 翌日 3 時以降にログを確認
   ```bash
   tail -n 50 /home/ec2-user/be-my-style/log/cron_recap_movie_cleanup.log
   ```

## 本番適用状況

本番 APP_ROOT は `/home/ec2-user/be-my-style`（`/var/www/be-my-style/current` は存在しないことを確認済み）。

スクリプトの default APP_ROOT は `/var/www/be-my-style/current` のまま（汎用値として保持）。
cron 登録時は必ず `APP_ROOT=/home/ec2-user/be-my-style` を明示すること。

cron の有効化は Phase 8-C で実施。詳細は [recap_movie_cleanup_production_checklist.md](recap_movie_cleanup_production_checklist.md) を参照。

---

## Phase 8-B: Storage Audit（孤立 / 不整合 検知）

### 概要

`Singing::RecapMovieStorageAuditService` を Phase 8-B で追加。
Admin Health Dashboard の "Storage Audit" セクションに表示。

**検知のみ・削除は行わない。**

### 検知項目

| 項目 | 条件 | 意味 |
|------|------|------|
| Completed without File | `status=completed` かつ `video_file` なし | S3 消失 / purge 競合の可能性 |
| Cleaned but Attached | `status=expired` + `cleaned_up_at` あり + `video_file` あり | `purge_later` 遅延 / 失敗の可能性 |

### Rails console で確認

```ruby
result = Singing::RecapMovieStorageAuditService.call
puts "completed_without_file: #{result[:completed_without_file_count]}"
puts "cleaned_but_attached:   #{result[:cleaned_but_attached_count]}"
puts "has_anomalies: #{result[:has_anomalies]}"
```

### 異常が検知された場合の対応

| 異常 | 対応 |
|------|------|
| Completed without File | S3 直接確認 / journalctl で purge_later ログを追って原因調査 |
| Cleaned but Attached | `purge_later` の再実行または S3 直接削除を検討（**要ユーザー確認**） |
