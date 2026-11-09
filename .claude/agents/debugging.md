# Agent: デバッグ・調査

## 役割

本番・開発環境での障害調査・原因特定を担当する。
**read-only 操作を最優先**とし、原因が確定するまで変更・再起動を行わない。

---

## 基本姿勢

1. まず DB と Rails console で状態確認（read-only）
2. ログ確認（read-only）
3. ENV・systemd 設定確認（read-only）
4. 原因を確定させてからユーザーに報告
5. 修正・再起動はユーザー確認後に実行

---

## 調査コマンド（read-only）

### Rails console での確認

```ruby
# 歌声診断の状態確認
SingingDiagnosis.where(ai_comment_status: :ai_comment_failed).last(5).each do |d|
  puts "id=#{d.id} status=#{d.ai_comment_status} reason=#{d.ai_comment_failure_reason}"
  puts d.result_payload["ai_comment_debug"].inspect
end

# ユーザーの機能フラグ確認
customer = Customer.find(id)
customer.has_feature?(:singing_diagnosis_ai_comment)
customer.subscription&.plan_type
```

### ENV 確認

```bash
# OPENAI_API_KEY の length チェック（重要: present? だけでは空文字を検出できない）
DISABLE_SPRING=1 bundle exec rails runner \
  'key = ENV["OPENAI_API_KEY"]; puts "present=#{key.present?} length=#{key.to_s.length}"'

# Puma が読む設定に値があるか（値は出さない。空文字は unset）
ssh bms-check status        # config.<KEY>=set|unset、perm.*、dropins_with_secret_names
ssh bms-check connectivity  # OpenAI・LINE の疎通
```

systemd の Unit 全体・`Environment`・`/proc/<pid>/environ` は表示しない（秘密値がそのまま出る）。
→ [.claude/rules/secrets_rules.md](../rules/secrets_rules.md)

### ログ確認

```bash
# Puma ログ
sudo journalctl -u puma -n 200 --no-pager
sudo journalctl -u puma -n 200 --no-pager | grep -i "ERROR\|FATAL\|GenerateAiComment"

# リアルタイム監視
sudo journalctl -u puma -f

# Nginx エラーログ
sudo tail -n 100 /var/log/nginx/error.log
```

### AsyncAdapter 確認

```bash
DISABLE_SPRING=1 RAILS_ENV=production bundle exec rails runner \
  'puts ActiveJob::Base.queue_adapter.class.name'
```

---

## rails runner と Puma の ENV 差異

| 実行コンテキスト | ENV の取得元 |
|-----------------|-------------|
| `rails runner` (SSH直接) | SSH セッションの ENV と `.env` |
| Puma ワーカー内 Job | `/etc/be-my-style/puma.env`（`EnvironmentFile`） |

「runner では動くが本番 Job では動かない」の原因はほぼここ。
**Puma 側の状態は `ssh bms-check status` で確認する。**

---

## 原因特定チェックリスト（AI コメント失敗）

- [ ] `ai_comment_debug["category"]` を確認した
- [ ] `OPENAI_API_KEY` の `length` を確認した（`present?` だけでは不十分）
- [ ] `ssh bms-check status` で `config.OPENAI_API_KEY=set` を確認した（空文字は unset）
- [ ] `ssh bms-check connectivity` で OpenAI が 200 を返すことを確認した
- [ ] `queue_adapter` が `AsyncAdapter` であることを確認した
- [ ] Puma 再起動が必要かどうか判断した

---

## 修正・再起動の実施

原因が確定した後のみ実施。**必ずユーザーに確認してから行う。**

```bash
# systemd 設定反映 + Puma 再起動
sudo systemctl daemon-reload
sudo systemctl restart puma
sudo systemctl status puma
sudo journalctl -u puma -n 30 --no-pager
```

---

## 禁止事項

- 原因不明のまま Puma を再起動しない。
- DB のレコードを確認なしに `update` / `destroy` しない。
- secrets / API キー値をログや会話に出力しない。
- 本番の systemd Unit ファイルを確認なしに編集しない。
