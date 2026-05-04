# BeMyStyle — Claude Code 運用ルール

このファイルは Claude Code / AI エージェントが安全に作業するための永続ルールです。
**作業前に必ず読み、全項目を遵守してください。**

---

## 絶対ルール（例外なし）

### ブランチ運用

- **main への直接作業・直接 push は禁止。** main push = 即本番デプロイのため、事故が直接ユーザー影響につながる。
- すべての変更は `feature/xxx` ブランチを切り、PR → レビュー → マージのフローで行う。
- ブランチ名例: `feature/fix-ai-comment-timeout`, `feature/add-singing-profile`

### 秘密情報・認証情報

- `config/credentials.yml.enc` / `config/master.key` / `.env` / `*.env.*` は**絶対に編集・コミット・内容参照しない。**
- 環境変数の値をログや出力に含めない。キー名のみ記載する。
- Stripe シークレットキー・OpenAI API キーの値はどのファイルにも書かない。

### アセット

- `public/assets/` 配下のコンパイル済みファイルは **commit 禁止。**
- アセット変更後は本番デプロイ時に `rails assets:precompile` を実行する。

### 本番サーバー

- EC2 本番サーバーへの直接操作（SSH・コマンド実行）は**事前確認必須。**
- systemd サービスの restart / stop は必ずユーザーに確認してから行う。

### Stripe 変更

- Stripe 関連コード（`app/services/stripe/`, Webhook, Plan/Price ID）の変更は **必ずユーザーに確認。**
- テスト環境と本番環境でキーが異なることを常に意識する。

---

## デプロイ前確認コマンド

```bash
# 混入チェック（不要ファイルが含まれていないか）
git diff --check

# Rails 起動確認
DISABLE_SPRING=1 bundle exec rails runner 'puts "boot ok"'

# アセットプリコンパイル確認（staging / 本番前）
RAILS_ENV=production bundle exec rails assets:precompile

# テスト
bundle exec rspec
```

---

## 開発ルール

### ブランチ命名

```
feature/<kebab-case-description>
fix/<kebab-case-description>
```

### コード品質

- コメントは「なぜそうしているか」が非自明な場合のみ記載する。
- デバッグ用 `puts` / `binding.pry` / `byebug` はコミット前に必ず削除する。
- `git diff --check` でホワイトスペースエラーを確認してからコミットする。

### テスト

- 新機能・バグ修正には RSpec を書く。
- `spec/services/`, `spec/jobs/`, `spec/helpers/` を優先してカバーする。

---

## OpenAI API キー運用注意（本番障害知見）

> 詳細は `docs/handover/ai_comment_debug.md` を参照。

### 重要ポイント

1. **`OPENAI_API_KEY` は存在するだけでなく「空文字でないこと」を必ず確認する。**
   - systemd の `Environment=OPENAI_API_KEY=` という行は、キーが存在するが値が空文字になる。
   - Rails の `ENV["OPENAI_API_KEY"].present?` ではなく **`.length > 0`** でチェックする。

2. **本番の AI コメント生成は Puma(systemd) 環境に依存する。**
   - `AsyncAdapter` のため、Job は Puma ワーカープロセス内で実行される。
   - systemd の環境変数設定ミスは Puma 再起動後まで反映されない。

3. **確認コマンド（本番サーバー上）:**
   ```bash
   # systemd の環境変数確認
   sudo systemctl show puma --property=Environment

   # Puma プロセスの環境変数確認
   sudo cat /proc/$(puma-pid)/environ | tr '\0' '\n' | grep OPENAI

   # Rails console で length チェック
   DISABLE_SPRING=1 bundle exec rails runner \
     'key = ENV["OPENAI_API_KEY"]; puts "exists=#{key.present?} length=#{key.to_s.length}"'
   ```

---

## 技術構成

| 項目 | 内容 |
|------|------|
| Rails | 6.1.7.3 |
| Ruby | 3.1.2 |
| DB | MySQL |
| インフラ | AWS EC2 |
| Web サーバー | Puma + Nginx |
| ストレージ | Amazon S3 |
| 決済 | Stripe |
| 歌声分析 API | FastAPI (singing_analyzer) |
| 認証 | Devise |
| テンプレート | HAML |
| スタイル | SCSS |
| ジョブキュー(本番) | Redis (ActionCable も Redis) |
| ジョブキュー(開発) | AsyncAdapter |

---

## ドメイン構成

| ドメイン | 概要 |
|----------|------|
| music | コミュニティ・セッション・バンド |
| singing | 歌声診断・AIコメント・ランキング |
| business | 法人向け・プレミアム機能 |
| learning | 学習コンテンツ |

---

## 参照ドキュメント

- [アーキテクチャ](docs/handover/architecture.md)
- [デプロイ手順](docs/handover/deployment.md)
- [歌声診断機能](docs/handover/singing.md)
- [AIコメント障害と対処](docs/handover/ai_comment_debug.md)
- [Stripe 注意事項](docs/handover/stripe_notes.md)
- [band診断デプロイメモ](docs/band_diagnosis_deploy_notes.md)
- [band診断リリースチェック](docs/band_diagnosis_release_checklist.md)
