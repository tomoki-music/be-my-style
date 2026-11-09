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
- **秘密値を含み得る設定・環境変数を丸ごと表示しない**（systemd の Unit 全体・`Environment`、`/proc/<pid>/environ`、`env`/`printenv`、`.env`、`/etc/be-my-style/`）。値を伏せる（`sed` で消す）のではなく、**許可した項目の状態（有無・長さ・件数・権限）だけ**を出す。詳細は [.claude/rules/secrets_rules.md](.claude/rules/secrets_rules.md)。

### アセット

- `public/assets/` 配下のコンパイル済みファイルは **commit 禁止。**
- アセット変更後は本番デプロイ時に `rails assets:precompile` を実行する。

### 本番サーバー

- Claude Code が本番に対して行うのは、確認専用の `ssh bms-check status` / `mail` / `connectivity` / `help` だけ（固定形式で状態を返す）。
- 管理用キー・`ec2-user` での SSH、秘密値の登録・変更、Puma 再起動、DB 変更は**利用者が自分のターミナルで行う**。Claude Code は手順を案内する。詳細は [docs/handover/production_access.md](docs/handover/production_access.md)。
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

3. **確認コマンド（値は出さない）:**
   ```bash
   # Claude Code（Mac）: Puma が読む設定に値があるか（空文字は unset と表示される）
   ssh bms-check status        # config.OPENAI_API_KEY=set|unset
   ssh bms-check connectivity  # openai: ... GET /v1/models -> 200

   # 利用者が本番サーバー上で確認する場合も同じ出力を使う
   sudo /usr/local/libexec/bms-status-root status
   ```
   - 秘密値は `/etc/be-my-style/puma.env`（root 600、`EnvironmentFile`）にあり、変更は利用者が `sudo bms-set-secret <KEY> --restart` で行う。
   - SSH で入って実行する `rails runner` は `.env` の ENV を使うため、Puma の ENV とは一致しない。

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
- [本番アクセスの分離（bms-check）](docs/handover/production_access.md)
- [秘密値・本番アクセスのルール](.claude/rules/secrets_rules.md)
- [Stripe 注意事項](docs/handover/stripe_notes.md)
- [ビジネス通知メールの送信元切り替え](docs/handover/business_mail_sender.md)
- [band診断デプロイメモ](docs/band_diagnosis_deploy_notes.md)
- [band診断リリースチェック](docs/band_diagnosis_release_checklist.md)
