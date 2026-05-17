# Achievement Recap Movie — Remotion Handoff Docs

> **対象者:** Remotion 動画テンプレート開発者  
> **目的:** Rails が生成する `recap_movie.json` を使って縦型動画（1080×1920）を Remotion で実装するための仕様書

---

## 1. 概要

BeMyStyle の「Achievement Recap Movie」は、ユーザーの年間 Achievement バッジをまとめた回顧動画機能です。

- Rails 側が JSON を生成（`AchievementRecapMovieBuilder` + `AchievementRecapMovieSerializer`）
- Remotion 側が JSON を受け取り、シーン単位でアニメーションを描画
- 最終的に mp4 として書き出し → S3 保存 → Share UI から共有

---

## 2. JSON Endpoint

```
GET /singing/badges/recap_movie.json?year=<YYYY>
```

### 認証

- `authenticate_customer!` が適用されている（Devise）
- **ログイン必須。** 未認証リクエストは 401 または login ページにリダイレクト
- 他ユーザーのデータは取得できない（`current_customer` ベース）

### パラメータ

| パラメータ | 型 | 必須 | 説明 |
|------------|-----|------|------|
| `year` | integer | 任意 | 対象年。省略時または不正値は当年にフォールバック |

### レスポンス例（`empty: false`）

```json
{
  "year": 2025,
  "title": "2025年の軌跡",
  "subtitle": "Legendary 達成の年",
  "total_duration": 40,
  "empty": false,
  "scenes": [
    {
      "index": 0,
      "type": "hero",
      "title": "2025年、あなたの歌声の物語。",
      "subtitle": "12件の Achievement を積み重ねた年",
      "body": "この1年間、あなたは歌い続けました。記録のひとつひとつが、あなたの成長の証です。",
      "duration": 6,
      "emotion": "emotional",
      "background_style": "cosmic",
      "badge": {
        "label": "パワフルボイス",
        "emoji": "🎤",
        "rarity": "epic",
        "earned_at": "2025-03-15",
        "description": "..."
      }
    }
  ]
}
```

### レスポンス例（`empty: true`）

```json
{
  "year": 2025,
  "title": "2025年の Recap",
  "subtitle": "",
  "total_duration": 0,
  "empty": true,
  "scenes": []
}
```

---

## 3. JSON Schema

### トップレベル

| フィールド | 型 | 説明 |
|------------|-----|------|
| `year` | integer | 対象年（例: `2025`） |
| `title` | string | 動画タイトル（例: `"2025年の軌跡"`） |
| `subtitle` | string | サブタイトル（例: `"Legendary 達成の年"`） |
| `total_duration` | integer | 全シーンの合計秒数 |
| `empty` | boolean | Achievement がない年は `true`。`true` の場合 `scenes` は空配列 |
| `scenes` | array | Scene オブジェクトの配列（順序保証あり） |

### Scene オブジェクト

| フィールド | 型 | 説明 |
|------------|-----|------|
| `index` | integer | 0 始まりのシーン順序番号 |
| `type` | string | シーンタイプ（後述） |
| `title` | string | シーン大見出し |
| `subtitle` | string | シーン小見出し |
| `body` | string | 本文テキスト |
| `duration` | integer | このシーンの尺（秒） |
| `emotion` | string | 感情トーン（後述） |
| `background_style` | string | 背景スタイル（後述） |
| `badge` | object \| null | バッジ情報。関連バッジがない場合は `null` |

### Badge オブジェクト

| フィールド | 型 | 説明 |
|------------|-----|------|
| `label` | string | バッジ名称 |
| `emoji` | string | バッジ絵文字 |
| `rarity` | string | `"common"` / `"rare"` / `"epic"` / `"legendary"` |
| `earned_at` | string \| null | 獲得日（ISO8601: `"2025-03-15"`） |
| `description` | string | バッジ説明文 |

---

## 4. Scene Type

各シーンのタイプと出現条件：

| `type` | 日本語 | 出現条件 | デフォルト duration |
|--------|--------|----------|-------------------|
| `hero` | オープニング | 常に含まれる（先頭固定） | 6秒 |
| `first_achievement` | 最初の一歩 | その年に1件以上 Achievement がある場合 | 6秒 |
| `growth` | 成長の記録 | Achievement が3件以上の場合 | 7秒 |
| `monthly_peak` | 最も輝いた月 | 突出したピーク月がある場合 | 6秒 |
| `legendary` | Legendary 達成 | Legendary レアリティのバッジを持つ場合 | 8秒 |
| `ending` | エンディング | 常に含まれる（末尾固定） | 7秒 |

**シーン順序は常に上記テーブルの順で出力される。** 条件を満たさないシーンはスキップされる。

---

## 5. background_style 対応案

| 値 | 想定ビジュアル | 使用シーン |
|----|--------------|-----------|
| `cosmic` | 宇宙・星空・深い紺色 | hero, ending |
| `sunrise` | オレンジ→ピンクのグラデーション | first_achievement |
| `aurora` | 緑〜紫のオーロラ | growth |
| `neon` | ネオン発光・シティナイト | monthly_peak |
| `dark_stage` | 暗いステージ・スポットライト | legendary |

---

## 6. emotion 対応案

| 値 | 意味 | アニメーション方向 |
|----|------|-------------------|
| `emotional` | 感動・じわっと | ゆっくりフェードイン、静かな動き |
| `hopeful` | 希望・前向き | 明るく上昇するモーション |
| `powerful` | 力強さ・高揚 | ダイナミックなズームや衝撃エフェクト |
| `nostalgic` | 懐かしさ・余韻 | フェードアウト、温かみのある色調 |

---

## 7. Remotion Props 変換案

Rails JSON → Remotion の `<Composition>` に渡す Props の変換例：

```typescript
// types.ts
export interface BadgeProps {
  label: string;
  emoji: string;
  rarity: "common" | "rare" | "epic" | "legendary";
  earned_at: string | null;
  description: string;
}

export interface SceneProps {
  index: number;
  type: "hero" | "first_achievement" | "growth" | "monthly_peak" | "legendary" | "ending";
  title: string;
  subtitle: string;
  body: string;
  duration: number; // 秒
  emotion: "emotional" | "hopeful" | "powerful" | "nostalgic";
  background_style: "cosmic" | "sunrise" | "neon" | "aurora" | "dark_stage";
  badge: BadgeProps | null;
}

export interface RecapMovieProps {
  year: number;
  title: string;
  subtitle: string;
  total_duration: number;
  empty: boolean;
  scenes: SceneProps[];
}
```

```typescript
// Root.tsx
import { Composition } from "remotion";
import { RecapMovie } from "./RecapMovie";
import type { RecapMovieProps } from "./types";

const props: RecapMovieProps = await fetch(
  `/singing/badges/recap_movie.json?year=${year}`,
  { headers: { Accept: "application/json" } }
).then((r) => r.json());

export const RemotionRoot = () => (
  <Composition
    id="RecapMovie"
    component={RecapMovie}
    durationInFrames={props.total_duration * 30} // 30fps
    fps={30}
    width={1080}
    height={1920}
    defaultProps={props}
  />
);
```

---

## 8. 動画尺設計

| シーン | duration | フレーム数（30fps） |
|--------|----------|-------------------|
| hero | 6秒 | 180 |
| first_achievement | 6秒 | 180 |
| growth | 7秒 | 210 |
| monthly_peak | 6秒 | 180 |
| legendary | 8秒 | 240 |
| ending | 7秒 | 210 |
| **合計（全シーン）** | **40秒** | **1200** |

- 最短構成（hero + ending のみ）: 13秒
- 最長構成（全6シーン）: 40秒
- `total_duration` はサーバー側で計算済みなので Remotion 側でそのまま使用できる

---

## 9. 動画仕様

| 項目 | 値 |
|------|-----|
| 解像度 | 1080 × 1920（縦型 9:16） |
| フレームレート | 30fps |
| フォーマット | mp4（H.264 推奨） |
| 用途 | Instagram Reels / TikTok / X（旧Twitter） 縦動画共有 |

---

## 10. 将来の生成フロー（未実装）

```
[1] Rails JSON Endpoint
    GET /singing/badges/recap_movie.json?year=YYYY
        ↓
[2] Remotion Props に変換
    TypeScript / Node.js で fetch して RecapMovieProps にマッピング
        ↓
[3] Remotion renderMedia() で mp4 生成
    renderMedia({ composition: "RecapMovie", outputLocation: "out.mp4" })
        ↓
[4] S3 にアップロード
    Presigned URL or AWS SDK で s3://bemystyle-movies/<customer_id>/recap_<year>.mp4
        ↓
[5] DB に保存
    GeneratedRecapMovie モデル（未作成）に S3 キー・生成日時を記録
        ↓
[6] Share UI
    フロント側で S3 Presigned URL を取得してダウンロード / SNS 共有ボタン表示
```

---

## 11. セキュリティ注意事項

- **`current_customer` のみアクセス可能。** サーバー側で認証済みユーザーのデータのみ返す
- Remotion render を外部 API として公開する場合は、**JWT または Signed URL** でリクエストを認可すること
- S3 に保存した動画は **Presigned URL（有効期限付き）** で配信する。Public ACL は使用しない
- render Job を非同期実行する場合は、**Job に customer_id を渡し、サーバー側で再認可**すること
- 生成動画には個人の Achievement データが含まれるため、**GDPR / 個人情報保護の観点から保存期間を設定**すること（例: 90日後に自動削除）

---

## 12. 未実装項目（将来フェーズ）

| 項目 | 説明 |
|------|------|
| Remotion テンプレート | 各 SceneType のアニメーションコンポーネント |
| render Job | `RemotionRenderJob`（Rails Sidekiq or外部マイクロサービス） |
| S3 アップロード | 生成 mp4 の S3 保存処理 |
| `GeneratedRecapMovie` モデル | 生成履歴・S3キー・ステータス管理 |
| Cleanup Job | 古い動画ファイルの定期削除 |
| Share UI | ダウンロードボタン・SNS共有ボタン |
| 進捗通知 | render 完了時の ActionCable / Push 通知 |

---

## 関連ファイル（Rails 側）

| ファイル | 役割 |
|----------|------|
| `app/services/singing/achievement_recap_movie_builder.rb` | JSON データ生成ロジック |
| `app/serializers/singing/achievement_recap_movie_serializer.rb` | JSON シリアライズ |
| `app/controllers/singing/badges_controller.rb` | `recap_movie` アクション |
| `app/views/singing/badges/recap_movie_preview.html.haml` | ブラウザプレビュー用ビュー |
| `config/routes.rb` | `/singing/badges/recap_movie` ルート定義 |
