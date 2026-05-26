# Recap Movie 本番手動テスト手順書

本番サーバーで Recap Movie を手動で 1 件生成・検証するための手順書。
**cron 登録前に必ずこの手順で動作確認すること。**

---

## 絶対にやらないこと

- cron 登録しない（この手順書はあくまで手動テスト用）
- 自動 kill しない（node / chromium / ffmpeg プロセスが残っていたら skip して手動確認）
- 本番で複数件生成しない（1 件ずつ確認する）
- Web リクエストから生成しない
- `GenerateRecapMovieJob.perform_later` を復活させない
- Sidekiq / Redis 導入しない
- `credentials/` `.env` 系ファイルを編集しない
- `public/assets` をコミットしない

---

## 事前確認

```bash
# メモリ確認（available が 350MB 以上あること）
free -h

# ディスク空き確認（1GB 以上あること）
df -h

# メモリ使用量 TOP プロセス確認
ps aux --sort=-%mem | head -10

# 残留メディアプロセス確認（node / chromium / chrome / ffmpeg）
pgrep -fa "node|chromium|chrome|ffmpeg" || true
```

**判断基準:**
- `free -h` の available が 350MB 未満 → 生成中止
- `df -h` の空き容量が 1GB 未満 → 生成中止
- `pgrep` で残留プロセスが見つかった → 手動確認後、残留理由を特定してから生成

---

## Puma 状態確認

```bash
sudo systemctl status puma
curl -I https://be-my-style.com/singing/recap_movies
```

Puma が正常稼働していること、HTTP 200 or リダイレクトが返ることを確認する。

---

## pending 件数確認

Admin ダッシュボードで確認:
`https://be-my-style.com/admin/singing/recap_movies`

または Rails runner で確認:
```bash
DISABLE_SPRING=1 RAILS_ENV=production bundle exec rails runner \
  'puts "pending: #{SingingGeneratedRecapMovie.pending.count}"'
```

---

## dry-run

まず dry-run を実行して、正しく pending movie を取得できるか確認する。

```bash
DRY_RUN=1 RAILS_ENV=production bin/run_pending_recap_movie_generation
```

**期待ログ:**
```
[Runner] Starting (RAILS_ENV=production DRY_RUN=1 TIMEOUT=900s)
[Runner] picked pending movie_id=XXX
[Runner] dry-run picked pending movie_id=XXX
[Runner] dry-run completed without generation
```

エラーが出た場合は生成に進まず、原因を特定する。

---

## 1 件生成実行

dry-run が問題なければ実行。

```bash
RAILS_ENV=production TIMEOUT_SECONDS=900 MIN_AVAILABLE_MB=350 bin/run_pending_recap_movie_generation
```

**期待ログ（成功時）:**
```
[Runner] Starting (RAILS_ENV=production DRY_RUN=0 TIMEOUT=900s)
[Runner] picked pending movie_id=XXX
[Runner] resource snapshot before generation
...（free / df / ps 出力）...
[Runner] generating movie_id=XXX (timeout=900s)
[Runner] completed movie_id=XXX
```

---

## 実行中監視

別ターミナルで実行状態を監視する。

```bash
# メモリ・プロセス監視（5秒おき）
watch -n 5 'free -h; echo; ps aux --sort=-%mem | head -10'

# Puma ログリアルタイム確認
sudo journalctl -u puma -f | grep -i "RecapMovie\|recap_movie"
```

---

## 生成後確認

### Rails runner で結果確認

```bash
DISABLE_SPRING=1 RAILS_ENV=production bundle exec rails runner \
  'movie = SingingGeneratedRecapMovie.order(updated_at: :desc).first; puts "id=#{movie.id} status=#{movie.status} error=#{movie.error_message}"'
```

### Admin 画面で確認

`https://be-my-style.com/admin/singing/recap_movies` で:
- completed または failed になっていること
- processing のまま止まっていないこと（stuck guard）

### Puma 確認

```bash
sudo systemctl status puma
curl -I https://be-my-style.com/singing/recap_movies
```

### ログ確認

```bash
tail -n 200 log/production.log | grep -i "recap_movie\|RecapMovie"
sudo journalctl -u puma -n 200 --no-pager | grep -i "recap_movie\|RecapMovie"
```

---

## 異常時の判断・中断基準

| 状況 | 対処 |
|------|------|
| メモリが 350MB 未満 | runner が自動 skip。Puma が安定するまで待つ |
| ディスクが 1GB 未満 | runner が自動 skip。不要ファイルを削除してから再試行 |
| 残留メディアプロセスがある | runner が自動 skip。プロセスが残った原因を調査 |
| 30 分以上 processing のまま | Admin ダッシュボードに警告が表示される。手動で failed に更新 |
| timeout（900 秒超） | runner がタイムアウトログを出して終了。movie は processing のままになる可能性があるため手動確認 |
| Puma がクラッシュした | `sudo systemctl status puma` で確認。`sudo systemctl restart puma` 前にログを確認 |
| failed になった | `error_message` カラムを確認して原因を特定 |

### stuck processing を手動で failed にする（要確認）

```ruby
# Rails console（本番サーバー上）
movie = SingingGeneratedRecapMovie.processing.where("updated_at < ?", 30.minutes.ago).first
# 確認
puts "id=#{movie.id} updated_at=#{movie.updated_at}"
# ユーザー確認後に実行
movie.mark_failed!("manually failed due to stuck processing")
```

---

## 動作確認チェックリスト（cron 登録前）

- [ ] `free -h` で available が 350MB 以上
- [ ] `df -h` で空き容量が 1GB 以上
- [ ] `pgrep` で残留メディアプロセスなし
- [ ] Puma が正常稼働
- [ ] dry-run が正常終了
- [ ] 1 件生成が completed になった
- [ ] 生成後も Puma が正常稼働
- [ ] Admin ダッシュボードで completed 件数が増加
- [ ] stuck processing が 0 件

すべてにチェックが入ったら cron 登録を検討できる。

---

## rollback 方法

### 生成した movie を pending に戻す

```bash
DISABLE_SPRING=1 RAILS_ENV=production bundle exec rails runner \
  'movie = SingingGeneratedRecapMovie.find(XXX); movie.update!(status: :pending, error_message: nil)'
```

### cron を止める

```bash
crontab -l
crontab -e  # 該当行を削除
```

### Puma 再起動

生成中に Puma が不安定になった場合:

```bash
sudo journalctl -u puma -n 50 --no-pager
sudo systemctl restart puma
sudo journalctl -u puma -n 50 --no-pager | grep "started puma"
```
