# デバッグルール

## 基本姿勢

- **read-only 操作を優先する。** ログ確認・DB 参照・ENV 確認から始める。
- 本番サーバーで破壊的操作（ファイル変更・サービス再起動）は確認なしに行わない。
- 原因が特定できる前に変更・再起動しない。「直った気がする」は禁止。

---

## AI コメント障害 デバッグ手順

### 障害パターン: AI コメントが生成されない

#### Step 1: DB で状態確認（read-only）

```ruby
# Rails console
diagnosis = SingingDiagnosis.where(ai_comment_status: :ai_comment_failed).last
diagnosis.ai_comment_failure_reason
diagnosis.result_payload["ai_comment_debug"]
```

`ai_comment_debug` の `category` を確認:
- `configuration` → API キー問題
- `timeout` → ネットワーク / OpenAI 応答遅延
- `request` → 接続エラー
- `response_format` → API レスポンス形式変更

#### Step 2: OPENAI_API_KEY を length チェック（空文字トラップ）

```bash
# 本番サーバー上
DISABLE_SPRING=1 bundle exec rails runner \
  'key = ENV["OPENAI_API_KEY"]; puts "present=#{key.present?} length=#{key.to_s.length}"'
```

- `present=true length=0` → **空文字セット（異常）**
- `present=false length=0` → キー未設定
- `present=true length=XX` (XX > 0) → 正常

**注意:** `present?` だけでは空文字を検出できない。必ず `length` を確認する。

#### Step 3: Puma が読む設定に値があるか（値は出さない）

```bash
# Claude Code（Mac）
ssh bms-check status        # config.OPENAI_API_KEY=set|unset（空文字は unset）
ssh bms-check connectivity  # openai: ... GET /v1/models -> 200 / 401
```

- `config.OPENAI_API_KEY=unset` → 未設定または空文字。**根本原因。**
- `set` なのに `connectivity` が 401 → キーが無効（失効・誤り）。

systemd の Unit 全体・`Environment`・`/proc/<pid>/environ` を表示して確かめることはしない（秘密値がそのまま出る）。
値の登録・変更は利用者が本番サーバー上で `sudo bms-set-secret OPENAI_API_KEY --restart` を実行する。

#### Step 5: AsyncAdapter = Puma ワーカー内実行の確認

```bash
DISABLE_SPRING=1 RAILS_ENV=production bundle exec rails runner \
  'puts ActiveJob::Base.queue_adapter.class.name'
```

`AsyncAdapter` の場合: Job は Puma ワーカー内で実行される。
→ **環境変数変更後は必ず Puma を再起動する。**

---

## Rails runner と Puma 環境の差異

| 実行方法 | 環境変数の取得元 |
|----------|----------------|
| `rails runner` (SSH 直接) | SSH セッションの ENV と `.env`（dotenv-rails） |
| Puma ワーカー内 Job | `/etc/be-my-style/puma.env`（`EnvironmentFile`）と systemd の drop-in |

この差異が「runner では動くが本番 Job では動かない」という事象を引き起こす。
**Puma 側の状態は `ssh bms-check status` で確認する（Step 3）。**

---

## ログ確認コマンド

```bash
# Puma ログ（AI コメント関連フィルタ）
sudo journalctl -u puma -n 200 --no-pager | grep -i "GenerateAiComment\|ai_comment\|openai"

# リアルタイム監視
sudo journalctl -u puma -f | grep -i "GenerateAiComment\|openai"

# Nginx エラーログ
sudo tail -n 100 /var/log/nginx/error.log

# 直近エラー全件
sudo journalctl -u puma -n 500 --no-pager | grep "ERROR\|FATAL"
```

---

## RDS / DB 接続注意

- 本番の DB は RDS（MySQL）。直接 SQL を実行する場合は**必ずユーザー確認**。
- `rails console` での `destroy` / `update` / `delete` はユーザーの許可なしに実行しない。
- 確認専用の参照クエリは OK。

```ruby
# OK: 参照のみ
SingingDiagnosis.where(ai_comment_status: :ai_comment_failed).count
Customer.find(id).has_feature?(:singing_diagnosis_ai_comment)

# 要確認: 更新系
diagnosis.update!(ai_comment_status: :pending)
SingingDiagnoses::GenerateAiCommentJob.perform_later(diagnosis.id)
```

---

## デバッグ後のクリーンアップ

- デバッグ用に追加した `Rails.logger.debug` / `puts` はコミット前に削除する。
- 一時的な ENV override はコミットに含めない。
- `rails console` での変更は必ずユーザーに報告する（変更内容・影響範囲）。
