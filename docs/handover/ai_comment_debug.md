# AI コメント障害 — 調査・デバッグガイド

## 障害の概要

本番環境で歌声診断の AI コメントが生成されない事象が発生した。
`ConfigurationError: OpenAI API key is not configured` が Puma ログに記録されていた。

## 根本原因

**systemd の Environment 設定で `OPENAI_API_KEY` が空文字になっていた。**

```ini
# /etc/systemd/system/puma.service (誤った例)
Environment=OPENAI_API_KEY=
```

この場合:
- `ENV["OPENAI_API_KEY"]` は `""` (空文字) を返す — `nil` ではない。
- `ENV["OPENAI_API_KEY"].present?` → **false** (空文字は present? が false)
- `ENV["OPENAI_API_KEY"].presence` → **nil**
- Rails 側の `configured_api_key` で `.presence` を使っているため `nil` と判定され `ConfigurationError` が発生。

## 正しい確認方法

### 1. systemd の設定確認

```bash
sudo systemctl show puma --property=Environment
```

出力例（正常）:
```
Environment=OPENAI_API_KEY=sk-xxxx...
```

出力例（異常 — 空文字）:
```
Environment=OPENAI_API_KEY=
```

### 2. Puma ワーカーの実環境変数を確認

```bash
# Puma の PID を取得
puma_pid=$(sudo systemctl show puma --property=MainPID --value)

# /proc から環境変数を確認
sudo cat /proc/$puma_pid/environ | tr '\0' '\n' | grep OPENAI
```

**ここで空文字が見えたら根本原因が確定。**

### 3. Rails runner で length チェック（推奨）

```bash
DISABLE_SPRING=1 bundle exec rails runner \
  'key = ENV["OPENAI_API_KEY"]; puts "exists=#{key.present?} length=#{key.to_s.length}"'
```

- `exists=true length=0` → 空文字セット（異常）
- `exists=false length=0` → キー未設定（異常）
- `exists=true length=XX` → 正常（XX > 0 であること）

### 4. AsyncAdapter の確認（本番で Sidekiq を使っていない場合）

```bash
DISABLE_SPRING=1 RAILS_ENV=production bundle exec rails runner \
  'puts ActiveJob::Base.queue_adapter.class.name'
```

本番で `ActiveJob::QueueAdapters::AsyncAdapter` が返る場合、
Job は Puma ワーカー内で実行される。**Puma 再起動なしに環境変数変更は反映されない。**

### 5. ログ確認

```bash
# リアルタイムで AI コメントのエラーを追う
sudo journalctl -u puma -f | grep -i "aicomment\|openai\|GenerateAiComment"

# 直近 200 行
sudo journalctl -u puma -n 200 --no-pager | grep -i "GenerateAiComment"
```

## 診断レコードで状況確認

```ruby
# 最新の診断を確認
diagnosis = SingingDiagnosis.where.not(ai_comment_status: :ai_comment_completed).last
diagnosis.ai_comment_status        # :ai_comment_failed など
diagnosis.ai_comment_failure_reason
diagnosis.result_payload["ai_comment_debug"]
```

`ai_comment_debug` ハッシュに以下が記録される:
```json
{
  "status": "failed",
  "category": "configuration",
  "error_class": "SingingDiagnoses::OpenAiResponsesClient::ConfigurationError",
  "message": "OpenAI API key is not configured...",
  "failed_at": "2025-xx-xxTxx:xx:xx+09:00",
  "rails_env": "production",
  "queue_adapter": "ActiveJob::QueueAdapters::AsyncAdapter"
}
```

`queue_adapter` が `AsyncAdapter` の場合、Puma ワーカー内で実行されていることを確認できる。

## 修正手順

1. `/etc/systemd/system/puma.service` を正しい値に修正
2. systemd リロード + Puma 再起動:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart puma
   ```
3. 上記の確認コマンドで length > 0 であることを確認
4. Rails console で失敗した診断に対して Job を再実行:
   ```ruby
   SingingDiagnoses::GenerateAiCommentJob.perform_later(diagnosis.id)
   ```

## AsyncAdapter の注意点

- 本番の ActiveJob は **AsyncAdapter**（Sidekiq 不使用）。
- Job は Puma のスレッドプール内で実行される。
- Puma を再起動すると実行中の Job は失われる可能性がある。
- 大量の Job が詰まっている場合は、Puma 再起動前に対処を検討する。
- Job の実行ログは Puma のログ（journalctl -u puma）に出力される。

## 改善された診断機能

今回の障害を受けて以下を改善した:

1. **`ai_comment_debug`** を `result_payload` に保存 — 失敗時の原因が DB に残るようになった。
2. **エラーカテゴリ分類** — `configuration` / `timeout` / `response_format` / `request` / `unexpected` に分類。
3. **`queue_adapter` をデバッグ情報に含める** — AsyncAdapter 起因の問題を特定しやすくした。
4. **development フォールバックコメント** — 開発環境では API キー未設定でもコメントが表示される。

## 再発防止チェックリスト

- [ ] `systemctl show puma --property=Environment` で `OPENAI_API_KEY` の length を確認
- [ ] `rails runner` で `key.to_s.length > 0` を確認
- [ ] Puma 再起動後に確認コマンドを再実行
- [ ] 本番 AI コメント生成テストを1件実施して `ai_comment_status: completed` になることを確認
