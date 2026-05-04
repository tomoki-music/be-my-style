# システムアーキテクチャ概要

## 技術スタック

| レイヤー | 技術 | バージョン |
|----------|------|-----------|
| 言語 | Ruby | 3.1.2 |
| フレームワーク | Ruby on Rails | 6.1.7.3 |
| DB | MySQL | - |
| Web サーバー | Nginx + Puma | - |
| インフラ | AWS EC2 | Amazon Linux |
| ストレージ | Amazon S3 | ActiveStorage |
| キャッシュ/PubSub | Redis | ActionCable 本番 |
| 認証 | Devise | - |
| テンプレート | HAML | - |
| スタイル | SCSS | - |
| 決済 | Stripe | - |
| 歌声分析 | FastAPI (Python) | singing_analyzer/ |
| AI コメント | OpenAI API (gpt-4.1-mini) | Responses API |

## ディレクトリ構成（主要部分）

```
be-my-style/
├── app/
│   ├── controllers/
│   │   ├── admin/          # 管理者機能
│   │   ├── business/       # 法人向け
│   │   ├── learning/       # 学習機能
│   │   ├── public/         # LP・公開ページ
│   │   └── singing/        # 歌声診断
│   ├── jobs/
│   │   └── singing_diagnoses/
│   │       ├── generate_ai_comment_job.rb  # AIコメント非同期生成
│   │       └── submit_to_analyzer_job.rb   # FastAPI連携
│   └── services/
│       └── singing_diagnoses/
│           ├── ai_comment_generator.rb
│           ├── analyzer_client.rb
│           ├── open_ai_responses_client.rb  # OpenAI API クライアント
│           └── result_persister.rb
├── singing_analyzer/       # FastAPI マイクロサービス
│   └── app/
│       └── services/diagnosis_analyzer.py
├── config/
│   ├── cable.yml           # ActionCable (本番: Redis)
│   └── puma.rb
└── docs/
    ├── band_diagnosis_deploy_notes.md
    ├── band_diagnosis_release_checklist.md
    └── handover/           # 引き継ぎドキュメント (このディレクトリ)
```

## ドメイン構成

### music ドメイン
- コミュニティ作成・参加
- セッションイベント管理
- バンドメンバー募集
- チャット機能

### singing ドメイン
- 歌声録音アップロード (S3)
- FastAPI による音声分析
- 診断結果の保存・表示
- AI コメント生成 (OpenAI)
- ランキング
- singing プロフィール

### business ドメイン
- プレミアムプラン管理 (Stripe)
- 法人向け機能

### learning ドメイン
- 学習コンテンツ管理

## ジョブキューの仕組み

```
本番環境:
  ActionCable → Redis (cable.yml: adapter: redis)
  ActiveJob  → AsyncAdapter (Puma ワーカー内で実行)
              ※ Sidekiq は使用していない

開発環境:
  ActionCable → async
  ActiveJob  → async
```

**重要:** 本番の ActiveJob は Sidekiq ではなく **AsyncAdapter** のため、
Job は Puma ワーカープロセス内で実行される。
Puma 再起動なしに環境変数変更を反映することはできない。

## 外部サービス連携

| サービス | 用途 | 認証方式 |
|----------|------|----------|
| AWS S3 | 音声ファイル・画像ストレージ | IAM ロール or credentials |
| OpenAI API | 歌声診断 AI コメント | OPENAI_API_KEY (ENV) |
| Stripe | サブスクリプション決済 | Stripe シークレットキー (ENV) |
| FastAPI (singing_analyzer) | 音声波形分析 | 内部 HTTP 通信 |
