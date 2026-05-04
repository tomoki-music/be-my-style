# RSpec テスト実行コマンド集

---

## 全テスト実行

```bash
bundle exec rspec
```

---

## ドメイン別テスト

```bash
# 歌声診断 (singing) 全体
bundle exec rspec spec/services/singing_diagnoses/
bundle exec rspec spec/jobs/singing_diagnoses/
bundle exec rspec spec/helpers/singing/
bundle exec rspec spec/requests/

# AI コメント関連
bundle exec rspec spec/services/singing_diagnoses/ai_comment_generator_spec.rb
bundle exec rspec spec/jobs/singing_diagnoses/generate_ai_comment_job_spec.rb

# LP・公開ページ
bundle exec rspec spec/requests/public/lp_spec.rb

# band 診断
bundle exec rspec spec/helpers/singing/diagnoses_helper_spec.rb
bundle exec rspec spec/services/singing_diagnoses/ai_comment_generator_spec.rb
```

---

## 単一ファイル・行指定

```bash
# ファイル単体
bundle exec rspec spec/services/singing_diagnoses/open_ai_responses_client_spec.rb

# 特定の example のみ
bundle exec rspec spec/services/singing_diagnoses/open_ai_responses_client_spec.rb:42
```

---

## 確認ポイント

- 全テスト通過していること（`0 failures`）
- `pending` が増えていないこと
- カバレッジが大きく下がっていないこと（SimpleCov 使用時）
- 変更したファイルに対応する spec ファイルが存在すること

---

## 危険ポイント

- **テスト通過 ≠ 機能正常。** 特に以下は手動確認が必要:
  - 外部 API 連携（OpenAI / FastAPI / Stripe）
  - ActiveStorage ファイルアップロード
  - ActionCable リアルタイム更新
  - Puma / systemd 依存の本番固有挙動

- `request spec` は環境差分で 302 リダイレクト前提が混ざることがある。
  CI 環境と手元で挙動が違う場合は `follow_redirects` の設定を確認する。

- `RAILS_ENV=test` でのテストは `AsyncAdapter` ではなく `TestAdapter` を使う。
  本番の `AsyncAdapter` 挙動は rails console や実機で確認する。

---

## CI でのテスト（GitHub Actions）

```yaml
# .github/workflows/ 配下を確認
# PR マージ前に CI が通っていることを必ず確認する
```

CI が落ちている状態で main にマージしない。
