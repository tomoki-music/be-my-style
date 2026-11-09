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

> 2026-11-09 以降、秘密値は `/etc/be-my-style/puma.env`（root 600、`EnvironmentFile`）にあります。
> systemd の `Environment` や `/proc/<pid>/environ` を表示すると秘密値がそのまま出るため、**表示しません**（[production_access.md](production_access.md)）。

### 1. Puma が読む設定に値があるか（値は出さない）

```bash
# Claude Code（Mac）。利用者が本番サーバー上で行う場合は sudo /usr/local/libexec/bms-status-root status
ssh bms-check status
```

- `config.OPENAI_API_KEY=set` → 1 文字以上の値がある
- `config.OPENAI_API_KEY=unset` → 未設定または**空文字**（今回の障害の状態）

### 2. キーが有効か

```bash
ssh bms-check connectivity
```

- `openai: key_length=NN GET /v1/models -> 200` → 有効
- `-> 401` → キーが無効（失効・誤り）

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

1. 利用者が本番サーバー上でキーを登録し直し、Puma を再起動する（入力は画面・引数・履歴に残らない）:
   ```bash
   sudo bms-set-secret OPENAI_API_KEY --restart
   ```
2. `ssh bms-check status` で `config.OPENAI_API_KEY=set`、`ssh bms-check connectivity` で 200 を確認
3. `ssh bms-check status` で `puma_active=active`・`http_root=200` を確認
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

- [ ] `ssh bms-check status` で `config.OPENAI_API_KEY=set`（空文字は unset）を確認
- [ ] `ssh bms-check connectivity` で OpenAI が 200 を返すことを確認
- [ ] Puma 再起動後に確認コマンドを再実行
- [ ] 本番 AI コメント生成テストを1件実施して `ai_comment_status: completed` になることを確認
