# BeMyStyle Agent Rules

このファイルは Codex CLI / GitHub Copilot / その他 AI Agent が BeMyStyle で作業するための共通ルールです。
作業前に必ず読み、`CLAUDE.md` と `docs/handover/` も必要に応じて参照してください。

---

## 最優先ルール

- `main` への直接 push は禁止。`main` push は本番デプロイに直結するため、必ず feature/fix ブランチで作業し、PR 経由で反映する。
- `config/credentials.yml.enc`、`config/master.key`、`.env`、`*.env.*` は編集・コミット・内容参照をしない。
- API キー、secret、credential、本番値をファイル・ログ・チャット・コミットメッセージに出さない。キー名のみ扱う。
- `public/assets/` 配下のコンパイル済みアセットはコミットしない。
- Stripe 関連変更はユーザー確認なしに進めない。決済、Webhook、Plan/Price ID、本番 Stripe 設定は特に慎重に扱う。
- 本番変更、EC2 操作、systemd restart/stop/reload、DB rollback は必ず事前にユーザーへ確認する。
- README や既存ドキュメントを破壊的に書き換えない。必要な追記にとどめる。
- 既存機能の仕様変更や挙動変更は、依頼範囲に含まれる場合だけ行う。

---

## 必須確認コマンド

変更内容に応じて、完了前に以下を確認する。

```bash
# ホワイトスペース・コンフリクトマーカー混入チェック
git diff --check

# Rails 起動確認
DISABLE_SPRING=1 bundle exec rails runner 'puts "boot ok"'

# CSS/JS/アセット関連変更、または本番反映前
RAILS_ENV=production bundle exec rails assets:precompile
```

RSpec が関係する変更では、対象 spec または `bundle exec rspec` も実行する。

---

## 技術構成

- Rails 6.1 系 / Ruby 3.1 系
- Devise
- HAML
- SCSS
- AWS EC2
- Puma
- Nginx
- FastAPI (`singing_analyzer/`)
- Stripe
- OpenAI API
- MySQL
- Amazon S3
- Redis / ActionCable

---

## ドメイン構成

- `music`: コミュニティ、セッション、バンド、チャット
- `singing`: 歌声診断、FastAPI 分析、AI コメント、ランキング
- `learning`: 学習コンテンツ
- `business`: 法人向け、プレミアム、Stripe 決済

---

## OpenAI API キー運用注意

本番の AI コメント生成は、Puma と systemd の環境変数に強く依存する。

- 本番 ActiveJob は Sidekiq ではなく `AsyncAdapter`。Job は Puma worker 内で実行される。
- systemd の `Environment=OPENAI_API_KEY=` は「存在するが空文字」の状態になる。
- `ENV["OPENAI_API_KEY"].present?` だけで安心しない。必ず `ENV["OPENAI_API_KEY"].to_s.length > 0` を確認する。
- systemd の env 変更は Puma 再起動後に反映される。
- API キー値そのものは絶対に出力しない。確認する場合は length や present/blank の状態だけ出す。

確認例:

```bash
DISABLE_SPRING=1 bundle exec rails runner \
  'key = ENV["OPENAI_API_KEY"]; puts "exists=#{key.present?} length=#{key.to_s.length}"'
```

本番サーバー調査が必要な場合は、必ずユーザー確認後に以下の観点で調べる。

- systemd の `Environment`
- Puma process env
- Rails runner での length
- `ActiveJob::Base.queue_adapter.class.name`
- `ai_comment_debug`
- Puma journal log

---

## AI デバッグ方針

- まず read-only 調査を優先する。
- 原因特定前に設定変更、再起動、再実行、データ修正をしない。
- ENV、process env、systemd、Rails runner、DB の `ai_comment_debug` を順に確認する。
- `ai_comment_status`、`ai_comment_failure_reason`、`result_payload["ai_comment_debug"]` を確認する。
- OpenAI / Stripe / AWS など外部サービスの secret 値は確認・出力しない。
- 本番での Job 再実行や Puma 再起動はユーザー確認後に行う。

---

## Stripe 変更時の注意

- Stripe 関連コード、Webhook、Plan/Price ID、サブスクリプション処理は事前にユーザーへ確認する。
- テストキーと本番キーを混在させない。
- Price ID は環境ごとに異なるため、安易にハードコードしない。
- Webhook secret や endpoint 変更は Stripe ダッシュボード、systemd env、Puma 再起動の整合性が必要。
- ユーザー課金に影響するため、小さな変更でも影響範囲を明記してから進める。

---

## 参照ドキュメント

- `CLAUDE.md`: Claude Code 向けの詳細運用ルール
- `docs/handover/architecture.md`: アーキテクチャ概要
- `docs/handover/deployment.md`: デプロイ手順
- `docs/handover/singing.md`: 歌声診断機能
- `docs/handover/ai_comment_debug.md`: OpenAI / AI コメント障害調査
- `docs/handover/stripe_notes.md`: Stripe 注意事項

---

## Agent 作業時の報告

作業完了時は以下を簡潔に報告する。

- 変更したファイル
- 実行した確認コマンドと結果
- 実行しなかった確認がある場合、その理由
- Claude 用ルールとの差分や、Agent 運用上の注意点
- 将来改善するとよい Agent 運用案
