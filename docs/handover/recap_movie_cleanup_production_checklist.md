# Recap Movie Cleanup — Production Activation Checklist (Phase 8-C)

## 概要

Cleanup cron を本番 EC2 に安全に有効化するための最終チェックリスト・運用 Runbook。

**対象 Job:** `Singing::CleanupGeneratedRecapMoviesJob`  
**実行スクリプト:** `bin/cleanup_expired_recap_movies`  
**予定頻度:** 深夜 3 時に 1 日 1 回 (`0 3 * * *`)  
**Health Dashboard:** `/admin/singing/recap_movies/health`

> ⚠️ 本番 SSH・cron 登録は **必ずユーザーが実施** する。  
> このドキュメントは安全に本番投入できる状態を整えるための手順書。

---

## 関連ドキュメント

| ドキュメント | 内容 |
|------------|------|
| [recap_movie_cleanup_scheduler.md](recap_movie_cleanup_scheduler.md) | スケジューラ設計・purge_later 注意・rollback 詳細 |
| [recap_movie_auto_retry_production_checklist.md](recap_movie_auto_retry_production_checklist.md) | Auto Retry cron 本番投入チェックリスト（参照テンプレート） |
| [recap_movie_e2e_check.md](recap_movie_e2e_check.md) | E2E 手順・Remotion 動作確認 |
| [deployment.md](deployment.md) | デプロイ全体手順 |
| [architecture.md](architecture.md) | システム構成・Puma/Nginx/Redis |

---

## Phase 1：cron 登録前確認チェックリスト

本番 SSH を行う前にローカルで完結する確認項目。

```
[ ] 1. main の最新コードを pull 済み
        git checkout main && git pull origin main

[ ] 2. runner script が存在・syntax OK
        bash -n bin/cleanup_expired_recap_movies

[ ] 3. runner script に実行権限あり
        ls -l bin/cleanup_expired_recap_movies
        # 期待: -rwxr-xr-x

[ ] 4. Rails 起動確認
        DISABLE_SPRING=1 bundle exec rails runner 'puts "boot ok"'
```

---

## Phase 2：cron 登録前確認チェックリスト（本番 EC2 上）

SSH 接続後、cron 登録前に行う確認。

```
[ ] 1. デプロイ済みコードが最新であること
        cd /home/ec2-user/be-my-style
        git log --oneline -3

[ ] 2. runner script が存在・実行権限あること
        ls -l /home/ec2-user/be-my-style/bin/cleanup_expired_recap_movies
        # 期待: -rwxr-xr-x

[ ] 3. cron ログディレクトリが writable
        touch /home/ec2-user/be-my-style/log/cron_recap_movie_cleanup.log
        # エラーなければ OK

[ ] 4. bundle path 確認
        ~/.rbenv/shims/bundle --version

[ ] 5. Rails runner 単体実行成功
        cd /home/ec2-user/be-my-style
        RAILS_ENV=production DISABLE_SPRING=1 ~/.rbenv/shims/bundle exec rails runner \
          'puts "boot ok"'
        # → "boot ok" が出れば OK

[ ] 6. expired_targets 件数確認（超重要）
        DISABLE_SPRING=1 RAILS_ENV=production ~/.rbenv/shims/bundle exec rails runner '
          puts "expired_targets=#{SingingGeneratedRecapMovie.expired_targets.count}"
        '
        # → 件数を記録しておく（手動実行後の変化確認に使う）

[ ] 7. Health Dashboard でベースライン記録
        # ブラウザで /admin/singing/recap_movies/health を開き、以下をメモ:
        # - Cleanup Pending: XX 件
        # - Recently Cleaned: XX 件
        # - Storage Audit 異常: あり / なし
        # → cron 登録後の変化と比較するため値を記録しておく

[ ] 8. runner script を手動で 1 回実行してログ確認
        APP_ROOT=/home/ec2-user/be-my-style \
          RAILS_ENV=production \
          /home/ec2-user/be-my-style/bin/cleanup_expired_recap_movies

        # 期待出力（標準出力）:
        # [...] cleanup_expired_recap_movies start app_root=... env=production
        # [...] cleanup_expired_recap_movies finish exit_status=0

[ ] 9. production.log で Job ログを確認
        grep RecapMovieCleanup /home/ec2-user/be-my-style/log/production.log | tail -20
        # 期待: [RecapMovieCleanup] done — total=N succeeded=N
        # → failed_ids= が出た場合は内容を確認し、原因を調査してから cron 登録を判断する

[ ] 10. Storage Audit 悪化なし確認
         # /admin/singing/recap_movies/health の Storage Audit を確認
         # - "Cleaned but Attached" が急増していないこと
         # - purge_later の遅延は想定内（数分後に解消されることが多い）
```

---

## Phase 3：cron 登録・登録後確認チェックリスト

```
[ ] 1. crontab に以下の行を追加（crontab -e）
        0 3 * * * APP_ROOT=/home/ec2-user/be-my-style /home/ec2-user/be-my-style/bin/cleanup_expired_recap_movies >> /home/ec2-user/be-my-style/log/cron_recap_movie_cleanup.log 2>&1

[ ] 2. 登録確認
        crontab -l | grep cleanup_expired_recap_movies
        # 追加した行が表示されれば OK

[ ] 3. 翌日 3 時以降にログを確認
        tail -n 50 /home/ec2-user/be-my-style/log/cron_recap_movie_cleanup.log
        # 期待: finish exit_status=0 が出ていること

[ ] 4. production.log に Job 実行ログが出ていることを確認
        grep RecapMovieCleanup /home/ec2-user/be-my-style/log/production.log | tail -20
        # 期待: [RecapMovieCleanup] done total=X succeeded=X の行があること

[ ] 5. Health Dashboard で変化を確認
        # /admin/singing/recap_movies/health を開き:
        # - Cleanup Pending が Phase 2 時点より減っていること
        # - Recently Cleaned が増えていること
        # - Storage Audit が悪化していないこと

[ ] 6. 運用作業ログ（本ドキュメント末尾テンプレート）に記録する
```

---

## 即 disable 条件

以下を検知した場合は **即座に cron を停止し、報告すること。**

| 異常 | 判定基準 | 確認方法 |
|------|---------|---------|
| 全件 cleanup 暴走 | expired_targets が 200 件を超えて消えている | Health Dashboard / DB カウント |
| Cleaned but Attached 急増 | Storage Audit の Cleaned but Attached が 5 件超 | Health Dashboard |
| purge_later 失敗ループ | S3 削除が完了せず repeatedly failing | production.log ERROR |
| CPU 異常上昇 | EC2 CPU が 80% 超を継続 | AWS CloudWatch / `top` |
| disk 急増 | `/home/ec2-user/be-my-style` のサイズが急増 | `df -h` |
| Job 例外大量発生 | `ERROR\|FATAL` が production.log に頻出 | `grep -c ERROR production.log` |

---

## disable 手順

```bash
# 1. cron を即停止（コメントアウト）
crontab -e
# → 対象行の先頭に # を付けて保存

# 2. 停止確認
crontab -l | grep cleanup_expired_recap_movies
# → # でコメントアウトされていること

# 3. 現在実行中の Job が終わるまで待つ（最大 2〜3 分）

# 4. 状態確認
grep RecapMovieCleanup /home/ec2-user/be-my-style/log/production.log | tail -10

# 5. 報告（disable 理由・時刻・影響範囲）
```

---

## rollback 条件と手順

| 条件 | 対応 |
|------|------|
| expire! が誤ったレコードに実行された | DB 手動修正（要確認・S3 復元は不可） |
| CleanupJob のロジックに致命的バグ発見 | git rollback + cron disable |

```bash
# コードロールバック
git log --oneline -5
git checkout <commit-hash>
sudo systemctl restart puma
sudo journalctl -u puma -n 30 --no-pager
```

> **注意:** `expire!` は非可逆操作。`status: expired` に変わったレコードを `completed` に戻すことはできない。
> S3 から削除済みの動画は復元不可。ロールバック前に影響範囲を確認すること。

---

## 長期運用監視ポイント

| 項目 | 確認頻度 | 正常な状態 |
|------|---------|-----------|
| cron ログのエラー率 | 週 1 | `exit_status=1` が週 1 件以下 |
| Cleanup Pending 推移 | 週 1 | 緩やかに減少、または安定 |
| Cleaned but Attached | 週 1 | 0 件（常時） |
| Completed without File | 月 1 | 0 件（増加は S3 問題の兆候） |
| Disk 使用量 | 月 1 | 急増なし |

---

## 運用作業ログ テンプレート

本番で cron 登録・変更・disable を行った際は必ず記録する。

```markdown
# Cleanup Cron Production Activation Log

## 基本情報
- Date（実施日時）:
- Operator（実施者）:
- Commit（デプロイ済みコミット hash）:

## Phase 2 cron 登録前確認
- Rails 起動確認: OK / NG
- expired_targets 件数（登録前）: XX 件
- 手動実行 exit_status: 0 / その他
- Job ログ（done total= succeeded=）:
- Health Dashboard ベースライン:
  - Cleanup Pending: XX
  - Recently Cleaned: XX
  - Storage Audit 異常: あり / なし

## Phase 3 cron 登録
- 登録日時:
- 登録した cron 行:
  ```
  0 3 * * * APP_ROOT=/home/ec2-user/be-my-style .../bin/cleanup_expired_recap_movies >> .../log/cron_recap_movie_cleanup.log 2>&1
  ```
- 翌日 cron 実行ログ確認: OK / NG（未実施の場合は後日記入）
- Health Dashboard 変化:
  - Cleanup Pending: XX → XX
  - Recently Cleaned: XX → XX

## Rollback 実施
- Rollback Needed: Yes / No
- Rollback 内容（Yes の場合）:

## Notes（特記事項）:
```
