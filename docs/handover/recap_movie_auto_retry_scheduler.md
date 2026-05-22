# Recap Movie Auto Retry Scheduler

## 目的

`SingingRecapMovieBatchFailure` のうち `auto_retry_due` スコープに該当するレコード（次回リトライ時刻が到来済み・上限未到達）に対して、自動的にリトライをかける定期バッチ。

1 回の実行で最大 20 件を処理する（`MAX_PER_RUN = 20`）。

## 対象 Job

```
Singing::RunRecapMovieAutoRetriesJob
```

場所: `app/jobs/singing/run_recap_movie_auto_retries_job.rb`

内部で呼ぶ Service:

```
Singing::RecapMovieAutoRetryService
```

場所: `app/services/singing/recap_movie_auto_retry_service.rb`

## runner script の場所

```
bin/run_recap_movie_auto_retries
```

本番 EC2 上のフルパス: `/home/ec2-user/be-my-style/bin/run_recap_movie_auto_retries`

## 手動実行方法

### ローカル開発環境（smoke test）

```bash
cd /path/to/be-my-style
RAILS_ENV=development APP_ROOT=$(pwd) BUNDLE_BIN=bundle \
  bin/run_recap_movie_auto_retries
```

または Job を直接実行:

```bash
DISABLE_SPRING=1 bundle exec rails runner \
  'Singing::RunRecapMovieAutoRetriesJob.perform_now'
```

### 本番 EC2 上（必ず事前にユーザー確認してから行う）

```bash
cd /home/ec2-user/be-my-style
APP_ROOT=/home/ec2-user/be-my-style /home/ec2-user/be-my-style/bin/run_recap_movie_auto_retries
```

正常終了時はログに `start` と `finish exit_status=0` が出る。

rails runner を直接確認したい場合:

```bash
cd /home/ec2-user/be-my-style
RAILS_ENV=production DISABLE_SPRING=1 ~/.rbenv/shims/bundle exec rails runner \
  'Singing::RunRecapMovieAutoRetriesJob.perform_now'
```

## cron 登録例

5 分に 1 回実行する（**今回は登録しない。Phase 7-D で本番適用する際に登録する**）。

```cron
*/5 * * * * APP_ROOT=/home/ec2-user/be-my-style /home/ec2-user/be-my-style/bin/run_recap_movie_auto_retries >> /home/ec2-user/be-my-style/log/cron_recap_movie_auto_retries.log 2>&1
```

## 実行頻度

5 分に 1 回（`*/5 * * * *`）

**理由:** `RecapMovieAutoRetryService` は 1 回あたり最大 20 件しか処理しない。失敗が積み上がった場合でも 5 分ごとに少量ずつ処理することで、本番負荷を一定に保てる。

## ログ出力先

| ログ種別 | パス |
|---------|------|
| cron script ログ | `/home/ec2-user/be-my-style/log/cron_recap_movie_auto_retries.log` |
| Rails production ログ | `/home/ec2-user/be-my-style/log/production.log` |

cron ログ確認:

```bash
tail -n 100 /home/ec2-user/be-my-style/log/cron_recap_movie_auto_retries.log
```

リアルタイム監視:

```bash
tail -f /home/ec2-user/be-my-style/log/cron_recap_movie_auto_retries.log
```

Rails ログ確認:

```bash
grep RunRecapMovieAutoRetriesJob /home/ec2-user/be-my-style/log/production.log | tail -n 50
```

期待するログ例:

```text
[2026-05-22 10:00:00 +0900] run_recap_movie_auto_retries start app_root=/home/ec2-user/be-my-style bundle_bin=/home/ec2-user/.rbenv/shims/bundle
[2026-05-22 10:00:03 +0900] run_recap_movie_auto_retries finish exit_status=0
```

Rails ログ（job 内部）:

```text
[RunRecapMovieAutoRetriesJob] done processed=3 succeeded=2 skipped=0 failed=1
```

## Health Dashboard での確認方法

URL: `/admin/singing/recap_movies/health`

確認すべき項目:

| 項目 | 正常な状態 |
|------|-----------|
| Auto Retry - Scheduled | 処理待ちの件数。実行後に減っていることを確認 |
| Auto Retry - Due Now | 0 に近づいていること（実行直後） |
| Auto Retry - Exhausted | 上限到達済み件数。増え続ける場合は根本原因を調査 |
| Auto Retry - Running | 実行中件数。長時間 Running のままの場合は異常 |
| Next Due At | 次回リトライ予定時刻。cron 間隔内に収まっていることを確認 |

## smoke test 手順

### ローカル環境での確認

```bash
# 1. syntax チェック
bash -n bin/run_recap_movie_auto_retries

# 2. development 環境でスクリプトを実行
RAILS_ENV=development APP_ROOT=$(pwd) BUNDLE_BIN=bundle \
  bin/run_recap_movie_auto_retries

# 3. Job を直接実行して戻り値を確認
DISABLE_SPRING=1 bundle exec rails runner \
  'result = Singing::RunRecapMovieAutoRetriesJob.perform_now; puts result.inspect'
```

### 本番 EC2 上での確認（事前確認必須）

```bash
# 1. スクリプトの存在と実行権限確認
ls -l /home/ec2-user/be-my-style/bin/run_recap_movie_auto_retries
# 期待: -rwxr-xr-x

# 2. 手動実行（1 回）
APP_ROOT=/home/ec2-user/be-my-style \
  /home/ec2-user/be-my-style/bin/run_recap_movie_auto_retries

# 3. ログ確認
tail -n 20 /home/ec2-user/be-my-style/log/cron_recap_movie_auto_retries.log

# 4. Health Dashboard で Scheduled / Due Now が変化したことを確認
# /admin/singing/recap_movies/health
```

## disable 方法（cron 登録後に止めたい場合）

### cron を一時停止する場合

```bash
# 本番 EC2 上
crontab -e  # 該当行の先頭に # を付けてコメントアウト
crontab -l  # コメントアウトされたか確認
```

### cron を完全に削除する場合

```bash
crontab -e  # 該当行を削除して保存
crontab -l  # 削除されたか確認
```

cron 登録・削除は本番サーバー操作のため、必ず事前にユーザー確認してから行う。

## rollback 方法

### コードをロールバックする場合

```bash
git log --oneline -5
git checkout <commit-hash>
# → デプロイ後に Puma を再起動する
sudo systemctl restart puma
```

### Auto Retry の上限 / 間隔パラメータを変更したい場合

`app/services/singing/recap_movie_auto_retry_service.rb` の以下を変更する:

```ruby
MAX_PER_RUN = 20  # 1 回あたりの処理上限件数
```

`SingingRecapMovieBatchFailure` の `next_auto_retry_at` 計算ロジックを変えた場合は、既存レコードの `next_auto_retry_at` が古い間隔のままになる点に注意。

### Exhausted になったレコードを手動リセットする場合（要確認）

```ruby
# Rails console — 必ずユーザーに確認してから実行
failure = SingingRecapMovieBatchFailure.find(id)
failure.update!(auto_retry_count: 0, next_auto_retry_at: Time.current, auto_retry_status: :scheduled)
```

## 注意事項

### perform_now vs perform_later

runner script は `perform_now` を使用する（同期実行）。

- **perform_now**: cron script プロセス内で同期実行。終了まで待ってから exit する。ログに結果が残る。
- **perform_later**: Puma の `AsyncAdapter` キューに enqueue するだけ。cron ログには enqueue の成否しか残らない。

cron での定期実行では `perform_now` が適切。

### AsyncAdapter と Puma の関係

本番の `queue_adapter` が `AsyncAdapter` の場合、`perform_later` で enqueue したジョブは Puma ワーカー内で実行される。Puma が再起動されるとキュー内のジョブが失われる。そのため runner script では `perform_now` で確実に実行する。

### 環境変数

`APP_ROOT` / `BUNDLE_BIN` は cron 登録時に明示する。スクリプトのデフォルト値（`/var/www/be-my-style/current`）は汎用値であり、本番 EC2 では動作しない。

```
# 正しい cron 行（本番 EC2 用）
APP_ROOT=/home/ec2-user/be-my-style /home/ec2-user/be-my-style/bin/run_recap_movie_auto_retries ...
```

### credentials / master.key

runner script は credentials や master.key に一切触れない。`RAILS_MASTER_KEY` は systemd の Environment に設定済みの値が使われる。

## 本番適用手順（Phase 7-D で実施）

1. 本番 EC2 に SSH 接続（事前確認必須）
2. デプロイ済みの `bin/run_recap_movie_auto_retries` が存在することを確認
   ```bash
   ls -l /home/ec2-user/be-my-style/bin/run_recap_movie_auto_retries
   ```
3. 実行権限を確認（`-rwxr-xr-x` であること）
4. 手動実行で動作確認
   ```bash
   APP_ROOT=/home/ec2-user/be-my-style /home/ec2-user/be-my-style/bin/run_recap_movie_auto_retries
   ```
5. Health Dashboard で結果を確認
   ```
   /admin/singing/recap_movies/health
   ```
6. cron 登録
   ```bash
   crontab -e
   ```
   追加する行:
   ```cron
   */5 * * * * APP_ROOT=/home/ec2-user/be-my-style /home/ec2-user/be-my-style/bin/run_recap_movie_auto_retries >> /home/ec2-user/be-my-style/log/cron_recap_movie_auto_retries.log 2>&1
   ```
7. 登録確認
   ```bash
   crontab -l
   ```
8. 5 分後にログを確認
   ```bash
   tail -n 50 /home/ec2-user/be-my-style/log/cron_recap_movie_auto_retries.log
   ```
9. Health Dashboard で Scheduled / Due Now / Exhausted を確認

## 本番適用状況

本番 APP_ROOT は `/home/ec2-user/be-my-style`（`/var/www/be-my-style/current` は存在しないことを確認済み）。

スクリプトのデフォルト APP_ROOT は `/var/www/be-my-style/current` のまま（汎用値として保持）。
cron 登録時は必ず `APP_ROOT=/home/ec2-user/be-my-style` を明示すること。

本番 EC2 への cron 登録は未実施。登録タイミングは Phase 7-D で判断する。
