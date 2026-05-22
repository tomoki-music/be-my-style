# Recap Movie Auto Retry — Production Activation Checklist

## 概要

Auto Retry cron を本番 EC2 に安全に有効化するための最終チェックリスト・運用 Runbook。

**対象バッチ:** `Singing::RunRecapMovieAutoRetriesJob`  
**実行スクリプト:** `bin/run_recap_movie_auto_retries`  
**予定頻度:** 5分に1回 (`*/5 * * * *`)  
**Health Dashboard:** `/admin/singing/recap_movies/health`

> ⚠️ 本番 SSH・cron 登録は **必ずユーザー確認後** に実施すること。  
> このドキュメントは「安全に本番投入できる状態を整える」ための手順書。

---

## 関連ドキュメント

| ドキュメント | 内容 |
|------------|------|
| [recap_movie_auto_retry_scheduler.md](recap_movie_auto_retry_scheduler.md) | スケジューラ設計・smoke test・rollback 詳細 |
| [recap_movie_e2e_check.md](recap_movie_e2e_check.md) | E2E 手順・Remotion 動作確認 |
| [recap_movie_cleanup_scheduler.md](recap_movie_cleanup_scheduler.md) | Movie 期限切れ cleanup スケジューラ |
| [deployment.md](deployment.md) | デプロイ全体手順 |
| [architecture.md](architecture.md) | システム構成・Puma/Nginx/Redis |

---

## Phase 1：デプロイ前確認チェックリスト

本番 SSH を行う前にローカルで完結する確認項目。

```
[ ] 1. main の最新コードを pull 済み
        git checkout main && git pull origin main

[ ] 2. runner script の syntax OK
        bash -n bin/run_recap_movie_auto_retries

[ ] 3. runner script に実行権限あり
        ls -l bin/run_recap_movie_auto_retries
        # 期待: -rwxr-xr-x

[ ] 4. Rails 起動確認
        DISABLE_SPRING=1 bundle exec rails runner 'puts "boot ok"'

[ ] 5. spec が全て green
        bundle exec rspec spec/jobs/singing/run_recap_movie_auto_retries_job_spec.rb
        bundle exec rspec spec/services/singing/recap_movie_auto_retry_service_spec.rb
        # 180 examples, 0 failures

[ ] 6. git diff --check でホワイトスペースエラーなし
        git diff --check

[ ] 7. public/assets がステージングに含まれていないこと
        git diff --staged --name-only | grep "public/assets"
        # → 何も出なければ OK

[ ] 8. credentials / master.key / .env が含まれていないこと
        git diff --staged --name-only | grep -E "credentials|master\.key|\.env"
        # → 何も出なければ OK
```

---

## Phase 2：cron 登録前確認チェックリスト

本番 EC2 に SSH 接続した直後、cron 登録前に行う確認。

```
[ ] 1. デプロイ済みコードが最新であること
        cd /home/ec2-user/be-my-style
        git log --oneline -3

[ ] 2. runner script が存在・実行権限あること
        ls -l /home/ec2-user/be-my-style/bin/run_recap_movie_auto_retries
        # 期待: -rwxr-xr-x

[ ] 3. cron ログディレクトリが writable
        ls -la /home/ec2-user/be-my-style/log/
        touch /home/ec2-user/be-my-style/log/cron_recap_movie_auto_retries.log
        # エラーなければ OK

[ ] 4. bundle path 確認
        which bundle || ~/.rbenv/shims/bundle --version

[ ] 5. Rails runner 単体実行成功
        cd /home/ec2-user/be-my-style
        RAILS_ENV=production DISABLE_SPRING=1 ~/.rbenv/shims/bundle exec rails runner \
          'puts "boot ok"'
        # → "boot ok" が出れば OK

[ ] 6. Job を perform_now で1回実行して動作確認
        cd /home/ec2-user/be-my-style
        RAILS_ENV=production DISABLE_SPRING=1 ~/.rbenv/shims/bundle exec rails runner \
          'result = Singing::RunRecapMovieAutoRetriesJob.perform_now; puts result.inspect'
        # → エラーなし、processed= の行が出れば OK

[ ] 7. Health Dashboard で現在状態を記録（ベースライン）
        # ブラウザで /admin/singing/recap_movies/health を開き、以下をメモ:
        # - Auto Retry Scheduled: XX 件
        # - Auto Retry Due Now: XX 件
        # - Auto Retry Exhausted: XX 件
        # - Auto Retry Running: XX 件
        # → 登録後の変化と比較するため、値を記録しておく

[ ] 8. runner script を手動で1回実行してログ確認
        APP_ROOT=/home/ec2-user/be-my-style \
          /home/ec2-user/be-my-style/bin/run_recap_movie_auto_retries

        tail -n 30 /home/ec2-user/be-my-style/log/cron_recap_movie_auto_retries.log
        # 期待:
        # [...] run_recap_movie_auto_retries start app_root=...
        # [...] run_recap_movie_auto_retries finish exit_status=0
```

---

## Phase 3：cron 登録・登録後確認チェックリスト

```
[ ] 1. crontab に以下の行を追加（crontab -e）
        */5 * * * * APP_ROOT=/home/ec2-user/be-my-style /home/ec2-user/be-my-style/bin/run_recap_movie_auto_retries >> /home/ec2-user/be-my-style/log/cron_recap_movie_auto_retries.log 2>&1

[ ] 2. 登録確認
        crontab -l | grep recap_movie_auto_retries
        # 追加した行が表示されれば OK

[ ] 3. 次の5分タイミングまで待つ（最大5分）

[ ] 4. cron ログに初回実行の記録が出たことを確認
        tail -n 50 /home/ec2-user/be-my-style/log/cron_recap_movie_auto_retries.log
        # 期待: finish exit_status=0 が出ていること

[ ] 5. production.log に Job 実行ログが出ていることを確認
        grep RunRecapMovieAutoRetriesJob \
          /home/ec2-user/be-my-style/log/production.log | tail -n 20
        # 期待: [RunRecapMovieAutoRetriesJob] done processed=X succeeded=X ...

[ ] 6. Health Dashboard で変化を確認
        # /admin/singing/recap_movies/health を開き:
        # - Due Now が 0 に近づいていること（実行直後）
        # - Running が 0 に戻っていること
        # - Scheduled が Phase 2 時点より減っていること（処理されていれば）

[ ] 7. Exhausted が急増していないことを確認
        # Phase 2 記録値と比較。1〜2件の増加は正常。急増は異常。

[ ] 8. 運用作業ログ（本ドキュメント末尾テンプレート）に記録する
```

---

## 即 disable 条件

以下の状態を検知した場合は **即座に cron を停止し、ユーザーに報告すること。**

| 異常 | 判定基準 | 確認方法 |
|------|---------|---------|
| Retry loop | 同一 movie_id が短時間に何度も retry される | `grep movie_id= production.log \| sort \| uniq -c` |
| CPU 異常上昇 | EC2 CPU が継続して 80% 超 | AWS CloudWatch / `top` |
| Disk 急増 | `/home/ec2-user/be-my-style` のサイズが急増 | `df -h` |
| Open3 runaway | `render_recap_movie.js` プロセスが大量残留 | `ps aux \| grep render_recap` |
| Chromium/node runaway | node/chromium プロセスが大量残留 | `ps aux \| grep chromium` |
| Exhausted 急増 | 1時間以内に Exhausted が 10件以上増加 | Health Dashboard |
| Job 例外大量発生 | `FATAL\|ERROR` が production.log に頻出 | `grep -c ERROR production.log` |
| Running が長時間残る | Running が15分以上 0 に戻らない | Health Dashboard |

---

## disable 手順

```bash
# 1. cron を即停止（コメントアウト）
crontab -e
# → 対象行の先頭に # を付けて保存

# 2. 停止確認
crontab -l | grep recap_movie_auto_retries
# → # でコメントアウトされていること

# 3. 実行中の Job が終わるまで待つ（最大5分）
watch -n 30 'grep Running /admin 2>/dev/null || \
  tail -n 5 /home/ec2-user/be-my-style/log/cron_recap_movie_auto_retries.log'

# 4. ユーザーに報告（disable 理由・disable 時刻・影響範囲）

# 5. 必要であれば完全削除
crontab -e  # 該当行を削除
crontab -l  # 確認
```

---

## rollback 条件

disable だけでなくコードレベルのロールバックが必要な場合。

| 条件 | 対応 |
|------|------|
| バグにより大量の movie を誤ったステータスに更新した | git rollback + DB 手動修正（要確認） |
| auto_retry_service のロジックに致命的バグを発見 | git rollback + cron disable |
| migration が本番 DB に悪影響を与えた | git rollback + db:rollback（要確認） |

```bash
# コードロールバック
git log --oneline -5
git checkout <commit-hash>
sudo systemctl restart puma
sudo journalctl -u puma -n 30 --no-pager  # 起動確認
```

---

## 初回 24 時間監視 Runbook

### 登録後 30 分（最初の確認）

```bash
# cron ログ確認（6回分実行されているはず）
tail -n 50 /home/ec2-user/be-my-style/log/cron_recap_movie_auto_retries.log

# 確認ポイント
# - finish exit_status=0 が 6 行以上あること
# - ERROR / failed が混入していないこと

# production.log 確認
grep RunRecapMovieAutoRetriesJob \
  /home/ec2-user/be-my-style/log/production.log | tail -n 20
# - processed=X succeeded=X の行があること

# Health Dashboard 確認
# Due Now が減少傾向にあること
# Running が 0 に戻っていること
```

### 登録後 3 時間

```bash
# exhausted trend 確認
grep "auto_retry_status.*exhausted" \
  /home/ec2-user/be-my-style/log/production.log | wc -l
# → 前回確認値と比較。急増していないこと

# render duration 確認（1件あたりの処理時間）
grep "duration=" /home/ec2-user/be-my-style/log/production.log | tail -n 20

# retry volume 確認（1時間あたりの処理件数）
grep "succeeded=" /home/ec2-user/be-my-style/log/production.log \
  | awk -F'succeeded=' '{print $2}' | awk '{s+=$1} END {print "total succeeded:", s}'

# disk 使用量確認
df -h /home/ec2-user/be-my-style
# → 急増していないこと（Remotion が tmp ファイルを残していないか）
```

### 登録後 24 時間（翌日確認）

```bash
# resolved rate 確認
# Health Dashboard で
# - Scheduled の件数が減っていること（処理済み）
# - Exhausted が想定範囲内（急増 = 根本原因あり）

# open failures 確認
# - Running が 0 になっていること
# - Due Now が 0 に近いこと

# disk 使用量確認
df -h /home/ec2-user/be-my-style

# cron ログの1日分確認
wc -l /home/ec2-user/be-my-style/log/cron_recap_movie_auto_retries.log
grep "exit_status=1\|failed" \
  /home/ec2-user/be-my-style/log/cron_recap_movie_auto_retries.log | wc -l
# → 失敗件数が多くないこと（1日で5件以上の失敗は要調査）

# Exhausted になったレコードの failure_reason 確認（read-only）
RAILS_ENV=production DISABLE_SPRING=1 ~/.rbenv/shims/bundle exec rails runner '
  failures = SingingRecapMovieBatchFailure.exhausted.order(updated_at: :desc).limit(10)
  failures.each do |f|
    puts "id=#{f.id} count=#{f.auto_retry_count} reason=#{f.failure_reason}"
  end
'
```

---

## 長期運用監視ポイント

| 項目 | 確認頻度 | 正常な状態 |
|------|---------|-----------|
| cron ログのエラー率 | 週1 | `exit_status=1` が週5件以下 |
| Exhausted 件数推移 | 週1 | 緩やかな増加（急増は根本原因あり） |
| Due Now（常時） | 障害時 | 0 に近いこと |
| Disk 使用量 | 月1 | 急増なし |
| render_recap_movie.js 残留プロセス | 週1 | 残留なし |

---

## 運用作業ログ テンプレート

本番で cron 登録・変更・disable を行った際は必ず記録する。

```markdown
# Auto Retry Production Activation Log

## 基本情報
- Date（実施日時）:
- Operator（実施者）:
- Commit（デプロイ済みコミット hash）:
- Branch:

## Phase 1 デプロイ前確認
- [ ] spec: XX examples, 0 failures
- [ ] git diff --check: OK / NG
- [ ] runner script syntax: OK / NG
- [ ] Rails 起動確認: OK / NG

## Phase 2 cron 登録前確認
- [ ] SSH 接続先: /home/ec2-user/be-my-style
- [ ] runner script 存在・権限: OK / NG
- [ ] perform_now 手動実行: OK / NG
- Health Dashboard ベースライン:
  - Scheduled: XX
  - Due Now: XX
  - Exhausted: XX
  - Running: XX

## Phase 3 cron 登録
- Cron Registered（登録日時）:
- 登録した cron 行:
  ```
  */5 * * * * APP_ROOT=... .../bin/run_recap_movie_auto_retries >> .../log/...
  ```
- 初回実行ログ確認: OK / NG
- 登録後 Health Dashboard:
  - Scheduled: XX
  - Due Now: XX
  - Exhausted: XX

## Smoke Test 結果
- cron ログ（初回実行）: OK / NG
- production.log Job ログ: OK / NG
- Health Dashboard 変化: OK / NG

## Rollback 実施
- Rollback Needed: Yes / No
- Rollback 内容（Yesの場合）:
- Rollback 後の状態:

## Notes（特記事項）:
```

---

## 障害時の連絡事項テンプレート

disable / rollback を行った際にユーザーに報告する内容。

```
【Recap Movie Auto Retry cron disable 報告】

- 発生日時:
- 検知方法: （Health Dashboard / ログ / 監視アラート）
- disable 実施日時:
- disable 方法: （cron コメントアウト / cron 削除）
- 異常の内容:
  - 症状:
  - 影響範囲: （Exhausted件数 / エラー件数 / 影響ユーザー数）
- rollback 実施: Yes / No
- 現在の状態:
- 根本原因調査状況:
- 再有効化の目処:
```

---

## 次フェーズへの準備

Phase 7-D 完了後の次フェーズ候補:

| フェーズ | 内容 |
|---------|------|
| **Phase 8-A** | Movie Expiry & Cleanup Lifecycle（古い mp4 cleanup・S3 最適化・expired movie 再生成導線） |
| Phase 8-B | Monitoring アラート自動化（Exhausted 急増を Slack 通知等） |
| Phase 8-C | Retry パラメータ調整（MAX_PER_RUN・バックオフ間隔の本番実績ベース最適化） |
