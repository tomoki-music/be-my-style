# 歌声診断機能 概要

## 機能概要

ユーザーが歌声を録音・アップロードすると、FastAPI による音声分析と OpenAI による AI コメントが生成される診断機能。

## 診断フロー

```
1. ユーザーが歌声を録音 → S3 にアップロード
2. SingingDiagnosis レコード作成 (status: pending)
3. SubmitToAnalyzerJob が非同期実行
   └→ FastAPI (singing_analyzer) へ HTTP リクエスト
   └→ 音程 / リズム / 表現 スコアを取得
4. ResultPersister が結果を保存 (status: completed)
5. GenerateAiCommentJob が非同期実行 (Premium ユーザーのみ)
   └→ OpenAI Responses API へリクエスト
   └→ ai_comment を保存 (ai_comment_status: completed)
6. 結果画面に診断結果 + AI コメントを表示
```

## パフォーマンスタイプ

| タイプ | 説明 |
|--------|------|
| vocal | ボーカル診断 |
| guitar | ギター診断 |
| bass | ベース診断 |
| drums | ドラム診断 |
| keyboard | キーボード診断 |
| band | バンドアンサンブル診断 |

## 主要モデル・サービス

| ファイル | 役割 |
|----------|------|
| `app/models/singing_diagnosis.rb` | 診断レコード |
| `app/jobs/singing_diagnoses/submit_to_analyzer_job.rb` | FastAPI 連携 Job |
| `app/jobs/singing_diagnoses/generate_ai_comment_job.rb` | AI コメント生成 Job |
| `app/services/singing_diagnoses/analyzer_client.rb` | FastAPI HTTP クライアント |
| `app/services/singing_diagnoses/open_ai_responses_client.rb` | OpenAI HTTP クライアント |
| `app/services/singing_diagnoses/ai_comment_generator.rb` | AI コメント生成ロジック |
| `app/services/singing_diagnoses/result_persister.rb` | 結果保存ロジック |

## result_payload の構造

```json
{
  "pitch_score": 75,
  "rhythm_score": 68,
  "expression_score": 82,
  "overall_score": 75,
  "specific": { ... },
  "quality_flags": { "low_confidence": false },
  "quality_message": "音量が小さいため参考値です",
  "analysis_debug": { "rms_mean": 0.045 },
  "ai_comment_debug": {
    "status": "failed",
    "category": "configuration",
    "error_class": "ConfigurationError",
    "failed_at": "2025-...",
    "queue_adapter": "ActiveJob::QueueAdapters::AsyncAdapter"
  }
}
```

## AI コメント機能

- **対象:** `has_feature?(:singing_diagnosis_ai_comment)` が true の Premium ユーザーのみ
- **モデル:** gpt-4.1-mini (デフォルト、credentials/ENV で変更可)
- **タイムアウト:** 20 秒 (デフォルト)
- **失敗時:** `ai_comment_status: :ai_comment_failed` + `ai_comment_failure_reason` に理由を保存

## FastAPI (singing_analyzer)

```
singing_analyzer/
├── app/
│   ├── main.py
│   ├── schemas.py
│   └── services/diagnosis_analyzer.py
└── tests/test_main.py
```

- 音声波形の RMS / ピッチ / リズムを分析する Python マイクロサービス。
- Rails から HTTP で連携する。

## ランキング機能

- スコアに基づいてユーザーランキングを集計・表示する。
- 歌声プロフィール (singing profile) と連携して公開/非公開を制御する。

## 開発環境での注意

- AI コメントは `development` 環境では OpenAI API キーが未設定でもフォールバックコメントが表示される。
- `analysis_debug` / `Payload確認` セクションは development のみ表示される。
- production では開発者向け情報は表示されない。

## 診断を Rails console で確認する

```ruby
diagnosis = SingingDiagnosis.last
diagnosis.status
diagnosis.ai_comment_status
diagnosis.ai_comment_failure_reason
diagnosis.result_payload["ai_comment_debug"]
diagnosis.result_payload.dig("specific", "balance")
```
