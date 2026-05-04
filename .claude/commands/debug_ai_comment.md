# AI コメント デバッグコマンド集

AI コメントが生成されない・失敗している場合の調査手順。

---

## 1. DB で現状確認（まずここから）

```ruby
# Rails console で実行
# 最新の失敗レコードを確認
diagnosis = SingingDiagnosis.where(ai_comment_status: :ai_comment_failed).last
puts diagnosis.ai_comment_status
puts diagnosis.ai_comment_failure_reason
puts diagnosis.result_payload["ai_comment_debug"].inspect
```

**確認ポイント:**
- `ai_comment_debug["category"]` で原因種別を特定する
  - `configuration` → API キー問題 → Step 2 へ
  - `timeout` → ネットワーク / OpenAI 遅延 → Step 5 へ
  - `request` → 接続エラー → Step 5 へ
- `queue_adapter` が `AsyncAdapter` かどうか確認する

**危険ポイント:**
- `result_payload` が `nil` の場合は `ai_comment_debug` が保存されていない古いレコードの可能性

---

## 2. OPENAI_API_KEY の length チェック（空文字トラップ）

```bash
# ローカル or 本番サーバー上
DISABLE_SPRING=1 bundle exec rails runner \
  'key = ENV["OPENAI_API_KEY"]; puts "present=#{key.present?} length=#{key.to_s.length}"'
```

**確認ポイント:**
- `present=true length=XX` (XX > 0) → 正常
- `present=true length=0` → **空文字セット（異常）** → Step 3 へ
- `present=false length=0` → キー未設定 → Step 3 へ

**危険ポイント:**
- `present?` だけでは空文字 `""` を検出できない。必ず `length` も確認する。

---

## 3. systemd 環境変数確認（本番サーバー上）

```bash
# systemd Unit の Environment 設定を確認
sudo systemctl show puma --property=Environment | grep OPENAI
```

**確認ポイント:**
- `OPENAI_API_KEY=sk-...` → 正常
- `OPENAI_API_KEY=` （値が空） → **根本原因**

```bash
# Puma ワーカープロセスの実環境変数を確認（より確実）
puma_pid=$(sudo systemctl show puma --property=MainPID --value)
sudo cat /proc/$puma_pid/environ | tr '\0' '\n' | grep OPENAI
```

**危険ポイント:**
- `rails runner` は SSH セッションの ENV を使う。Puma は systemd の ENV を使う。
- 両者が異なる場合があるため、必ず Puma プロセスの ENV を直接確認する。

---

## 4. AsyncAdapter の確認

```bash
DISABLE_SPRING=1 RAILS_ENV=production bundle exec rails runner \
  'puts ActiveJob::Base.queue_adapter.class.name'
```

**確認ポイント:**
- `ActiveJob::QueueAdapters::AsyncAdapter` → Job は Puma ワーカー内で実行される
- 環境変数変更後は**必ず Puma を再起動**してから再確認する

---

## 5. Puma ログ確認

```bash
# AI コメント関連ログを抽出
sudo journalctl -u puma -n 300 --no-pager | grep -i "GenerateAiComment\|openai\|ai_comment"

# リアルタイム監視（Job 実行時）
sudo journalctl -u puma -f | grep -i "GenerateAiComment\|openai"

# エラー全件
sudo journalctl -u puma -n 500 --no-pager | grep "ERROR\|FATAL"
```

**確認ポイント:**
- `[GenerateAiCommentJob] Failed: category=configuration` → API キー問題
- `[GenerateAiCommentJob] Failed: category=timeout` → タイムアウト
- Job 自体のログが出ていない → Job が enqueue されていない可能性

---

## 6. 修正後の動作確認

```bash
# systemd リロード + Puma 再起動
sudo systemctl daemon-reload
sudo systemctl restart puma

# 再起動確認
sudo systemctl status puma
sudo journalctl -u puma -n 30 --no-pager
```

```ruby
# Rails console で Job を手動実行
diagnosis = SingingDiagnosis.where(ai_comment_status: :ai_comment_failed).last
SingingDiagnoses::GenerateAiCommentJob.perform_later(diagnosis.id)

# しばらく後に結果確認
diagnosis.reload
diagnosis.ai_comment_status   # :ai_comment_completed になれば成功
```

**危険ポイント:**
- Job 再実行前に `diagnosis.customer.has_feature?(:singing_diagnosis_ai_comment)` が true であることを確認する
- `diagnosis.completed?` が true であることも確認する
