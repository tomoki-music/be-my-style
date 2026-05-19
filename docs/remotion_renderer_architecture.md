# Remotion Renderer Architecture 設計書

> **対象フェーズ:** Phase 4-B（設計のみ。本実装は別ブランチで行う）  
> **作成日:** 2026-05-19  
> **ステータス:** Draft

---

## 1. 全体アーキテクチャ概要

```
[User Request]
      ↓
RecapMovieRequestService
  → SingingGeneratedRecapMovie (status: pending)
      ↓
GenerateRecapMovieJob (ActiveJob)
      ↓
Singing::RecapMovieRenderer  ← Rails側 Service Object（新規作成予定）
      ↓ system() / Open3.popen3
Node.js Renderer Process
  （bemystyle-reel/ 内の render スクリプト）
      ↓ npx remotion render
Remotion renderMedia()
  → mp4 出力 (tmp/generated_recap_movies/<uuid>/recap_<year>.mp4)
      ↓
ActiveStorage attach (video_file)
  → S3 upload（ActiveStorage が自動処理）
      ↓
SingingGeneratedRecapMovie (status: completed)
```

---

## 2. 採用アーキテクチャ: 案B（Node Renderer Service 分離）

### 候補比較

| 案 | 概要 | メリット | デメリット |
|----|------|----------|-----------|
| **A: Rails内 system() 直呼び** | Rails Job から直接 `npx remotion render` を実行 | 構成がシンプル。追加インフラ不要 | Rails プロセスと同一ホストに Node/Chromium/ffmpeg が必要。メモリ負荷が Puma に影響 |
| **B: Node Renderer Service 分離（推奨）** | `bemystyle-reel/` 内に独立した render スクリプトを置き、Rails Job から呼び出す | Rails と描画責務が明確に分離。将来 Lambda 移行も容易。`bemystyle-reel/` はすでに存在 | EC2 に Node 実行環境が必要。初期セットアップコスト |
| **C: Lambda Renderer** | AWS Lambda でレンダリング | スケールアウト容易。Puma に影響ゼロ | Lambda の 15分制限・ストレージ制限あり。設定複雑。コスト予測難 |

### 推奨: 案B を選択する理由

1. **`bemystyle-reel/` がすでに存在する** — Remotion 4.x・TypeScript・`@remotion/renderer` がインストール済みであり、ゼロから環境構築する必要がない。
2. **EC2 単一ホストで完結** — 現在のインフラ構成（AWS EC2 単台）に合致する。Lambda 移行は将来のスケール時に検討できる。
3. **Rails と Node の責務が明確に分離** — Rails は status 管理・queue・ActiveStorage に専念し、Remotion は描画のみに専念する。
4. **MVP → 本番への移行コストが最小** — ローカル render スクリプトを本番で動かすだけで済む。

---

## 3. 責務分離

### Rails 側の責務

| 責務 | 場所 |
|------|------|
| リクエスト受付・バリデーション | `RecapMovieRequestService` |
| status 遷移管理 (pending → processing → completed / failed) | `SingingGeneratedRecapMovie` モデル |
| ActiveJob キュー投入 | `GenerateRecapMovieJob` |
| Renderer プロセス呼び出し | `Singing::RecapMovieRenderer`（新規作成予定） |
| 一時ファイルパス管理・クリーンアップ | `Singing::RecapMovieRenderer` |
| ActiveStorage attach・S3 upload | `SingingGeneratedRecapMovie#video_file` |
| retry・タイムアウト管理 | `GenerateRecapMovieJob` |
| cleanup（期限切れ動画削除） | `CleanupGeneratedRecapMoviesJob`（実装済み） |

### Node / Remotion 側の責務

| 責務 | 場所 |
|------|------|
| JSON Props の受け取り（stdin or ファイル経由） | `bemystyle-reel/scripts/render_recap_movie.ts`（新規作成予定） |
| Remotion Composition 登録（RecapMovie） | `bemystyle-reel/src/Root.tsx`（追記予定） |
| シーン別アニメーション描画 | `bemystyle-reel/src/compositions/singing/RecapMovie.tsx`（新規作成予定） |
| mp4 書き出し（H.264 / 720p） | `@remotion/renderer` の `renderMedia()` |
| 出力ファイルパスを stdout に返す | `bemystyle-reel/scripts/render_recap_movie.ts` |

---

## 4. 実行フロー詳細

```
GenerateRecapMovieJob#perform(movie_id)
  ↓
1. SingingGeneratedRecapMovie.find(movie_id)
   └─ なければ warn して return

2. movie.mark_processing!

3. tmp_dir = "tmp/generated_recap_movies/#{SecureRandom.uuid}"
   FileUtils.mkdir_p(tmp_dir)

4. json_path = "#{tmp_dir}/props.json"
   File.write(json_path, movie.source_json.to_json)

5. output_path = "#{tmp_dir}/recap_#{movie.year}.mp4"

6. Singing::RecapMovieRenderer.call(
     json_path:,
     output_path:,
     movie:
   )
   ↓
   6a. node_script = Rails.root.join("../bemystyle-reel/scripts/render_recap_movie.js")
   6b. cmd = "node #{node_script} #{json_path} #{output_path}"
   6c. stdout, stderr, status = Open3.capture3(cmd, timeout: 300)
   6d. status.success? でなければ raise

7. movie.video_file.attach(
     io:           File.open(output_path),
     filename:     "recap_#{movie.year}_#{movie.customer_id}.mp4",
     content_type: "video/mp4"
   )

8. movie.mark_completed!

9. FileUtils.rm_rf(tmp_dir)  # ensure 節でクリーンアップ

rescue → movie.mark_failed!(e.message)
         FileUtils.rm_rf(tmp_dir) if tmp_dir && Dir.exist?(tmp_dir)
```

---

## 5. 一時ファイル戦略

### ディレクトリ構成

```
Rails.root/
  tmp/
    generated_recap_movies/
      <uuid>/              ← job ごとに UUID で分離
        props.json         ← Remotion に渡す JSON
        recap_<year>.mp4   ← 生成された mp4（attach 後に削除）
```

### 設計方針

| 課題 | 対策 |
|------|------|
| **race condition** | job ごとに `SecureRandom.uuid` のディレクトリを使う。同一 movie_id の並行実行は `movie.pending?` チェックで防ぐ（既に `processing` ならスキップ） |
| **partial file（render 途中失敗）** | `rescue` 節で必ず `FileUtils.rm_rf(tmp_dir)` を実行（ensure 節推奨） |
| **retry 時のゴミファイル** | retry 時は新たな UUID ディレクトリを作る。前回ディレクトリは ensure で削除済みのはず |
| **disk full 対策** | 生成 mp4 は attach 直後に削除。cleanup job が定期実行されているため、長期残留なし |
| **ffmpeg / Chromium crash** | `Open3.capture3` のタイムアウト（300秒）で強制終了。stderr をログに記録してから `mark_failed!` |
| **起動時の残骸** | サーバー起動時に `tmp/generated_recap_movies/` を一括クリーンアップするか、24時間以上経過したディレクトリを cleanup job で削除 |

### .gitignore 追記（予定）

```
tmp/generated_recap_movies/
```

---

## 6. Queue 戦略

### AsyncAdapter の危険性

| リスク | 内容 |
|--------|------|
| **Puma ワーカー内で実行** | mp4 生成は 30〜120秒かかる。その間 Puma ワーカーが占有され、Web リクエストの応答が遅延する |
| **プロセス kill 耐性ゼロ** | Puma 再起動（デプロイ）で Job が途中で失われる。`processing` のまま止まるリスク |
| **メモリ** | Node + Chromium + ffmpeg は 1〜2GB 消費することがある。Puma ワーカーと同居は危険 |

### 推奨: Sidekiq 移行

| 項目 | 内容 |
|------|------|
| **タイミング** | Recap Movie 本実装前に Sidekiq を導入する（Redis は ActionCable でも既に使用中） |
| **queue 名** | `:recap_movie`（専用 queue。Web リクエスト処理の queue とは分離） |
| **concurrency** | recap_movie queue の concurrency = 1〜2 に制限（Node + Chromium のメモリ負荷を考慮） |
| **タイムアウト** | `sidekiq_options timeout: 360`（6分。render 上限 300秒 + 余裕） |

```ruby
# 将来の GenerateRecapMovieJob
class Singing::GenerateRecapMovieJob < ApplicationJob
  queue_as :recap_movie
  sidekiq_options retry: 2, timeout: 360
end
```

### MVP フェーズ（Sidekiq 未導入時）

AsyncAdapter のまま動かす場合の暫定策:

- **concurrency を 1 に制限**（同時実行 1 件まで。`movie.pending?` チェックで自然に直列化される）
- **短い動画（15〜30秒）に限定**（render 時間を短縮）
- Puma ワーカー数を増やして影響を緩和

---

## 7. ffmpeg / Remotion 必要要件

### 実行環境（EC2）に必要なもの

| 依存 | バージョン目安 | 用途 |
|------|--------------|------|
| Node.js | 18.x 以上（LTS） | Remotion render スクリプト実行 |
| npm / npx | Node.js に同梱 | `@remotion/renderer` の呼び出し |
| Chromium | 最新安定版（Remotion が自動管理） | ヘッドレスレンダリング |
| ffmpeg | 6.x 以上推奨 | mp4 エンコード（Remotion 内部で使用） |
| ディスク空き容量 | 最低 2GB 推奨 | 一時ファイル・Chromium キャッシュ |

### render 時間目安（720p / 30fps）

| 動画尺 | 目安時間 | 備考 |
|--------|--------|------|
| 15秒（MVP） | 30〜60秒 | EC2 t3.small 程度で推定 |
| 30秒 | 60〜120秒 | |
| 40秒（全シーン） | 90〜180秒 | Legendary シーンが含まれる場合 |

> render 時間はマシンスペック・アニメーション複雑度に大きく依存する。本番導入前に EC2 実機で計測すること。

---

## 8. ActiveStorage attach タイミングと status 遷移

```
pending
  ↓ (GenerateRecapMovieJob#perform 開始時)
processing
  ↓ (Node render 完了 → mp4 ファイルが存在する)
  ↓ video_file.attach(...)  ← ここで S3 upload が発生
  ↓ (S3 upload 完了)
completed
  or
failed  (いずれかの段階で例外が発生した場合)
```

### 注意点

| タイミング | 内容 |
|-----------|------|
| `processing` への遷移 | Job 開始直後。Node render 開始前に遷移する（ユーザーへの「生成中」表示のため） |
| `video_file.attach` | mp4 ファイルが完全に書き出されたことを確認してから attach する。`partial file` を attach しないよう、render の exit code を必ずチェックする |
| `completed` への遷移 | attach が成功（`video_file.attached?` が true）になってから遷移する |
| `failed` への遷移 | render 失敗・attach 失敗・タイムアウトのいずれでも `mark_failed!` を呼ぶ |
| 一時ファイルの削除 | `completed` 遷移後（または `failed` 時）に `ensure` 節で `FileUtils.rm_rf(tmp_dir)` を必ず実行 |

---

## 9. エラーハンドリング設計

| エラーケース | 検出方法 | 対処 |
|------------|---------|------|
| **render timeout** | `Open3.capture3` の timeout オプション | `Timeout::Error` を rescue → `mark_failed!("render timeout")` |
| **Node crash / 異常終了** | `status.exitstatus != 0` | stderr をログ記録 → `mark_failed!(stderr)` |
| **ffmpeg missing** | stderr に "ffmpeg: command not found" | エラーメッセージで判定 → `mark_failed!` + アラート |
| **Chromium missing** | Remotion が起動時に検出 | 同上 |
| **partial mp4（書き出し途中で中断）** | exit code != 0 かつ output_path が存在する | render 失敗時は attach しない。ensure でファイル削除 |
| **disk full** | `Errno::ENOSPC` | rescue → `mark_failed!` + アラート（ディスク監視推奨） |
| **S3 upload failure** | `ActiveStorage` の例外 | rescue → `mark_failed!("S3 upload failed: #{e.message}")` |
| **movie が見つからない** | `find_by` が nil を返す | warn ログを出して return（既存の実装通り） |
| **movie が pending でない** | `movie.pending?` チェック | return（既存の実装通り） |

---

## 10. Node render スクリプト設計（`bemystyle-reel/scripts/render_recap_movie.ts`）

Rails から呼び出される Node スクリプトの責務と I/O 設計。

### 呼び出し形式

```bash
node scripts/render_recap_movie.js <json_path> <output_path>
```

### スクリプトの責務

```typescript
// 擬似コード
import { renderMedia, selectComposition } from "@remotion/renderer";

const [jsonPath, outputPath] = process.argv.slice(2);
const props = JSON.parse(fs.readFileSync(jsonPath, "utf-8"));

const composition = await selectComposition({
  serveUrl: bundleLocation,
  id: "RecapMovie",
  inputProps: props,
});

await renderMedia({
  composition,
  serveUrl: bundleLocation,
  codec: "h264",
  outputLocation: outputPath,
  // MVP: 720p に制限
  scale: 720 / 1080,
  crf: 23,
});

// 成功時は exit 0 のみ。Rails 側でファイル存在確認する
process.exit(0);
```

### エラー時

- `console.error(e.message)` で stderr に出力
- `process.exit(1)` で終了
- Rails 側は exit code と stderr を見て `mark_failed!` を呼ぶ

---

## 11. 新規作成予定ファイル一覧

### Rails 側

| ファイル | 役割 |
|----------|------|
| `app/services/singing/recap_movie_renderer.rb` | Node スクリプト呼び出し・一時ファイル管理の Service Object |

### `bemystyle-reel/` 側

| ファイル | 役割 |
|----------|------|
| `scripts/render_recap_movie.ts` | Rails から呼び出される render エントリポイント |
| `src/compositions/singing/RecapMovie.tsx` | Recap Movie Composition（全シーン結合） |
| `src/compositions/singing/scenes/HeroScene.tsx` | hero シーンコンポーネント |
| `src/compositions/singing/scenes/FirstAchievementScene.tsx` | first_achievement シーンコンポーネント |
| `src/compositions/singing/scenes/GrowthScene.tsx` | growth シーンコンポーネント |
| `src/compositions/singing/scenes/MonthlyPeakScene.tsx` | monthly_peak シーンコンポーネント |
| `src/compositions/singing/scenes/LegendaryScene.tsx` | legendary シーンコンポーネント |
| `src/compositions/singing/scenes/EndingScene.tsx` | ending シーンコンポーネント |
| `src/types/recap_movie.ts` | RecapMovieProps / SceneProps 型定義 |

---

## 12. MVP 推奨仕様

### 目標

「最小限の構成で動く mp4 を生成できること」を最初のマイルストーンとする。

### MVP スペック

| 項目 | MVP 値 | 理由 |
|------|-------|------|
| 解像度 | 720p（1080×1920 の 0.666× scale） | 1080p はレンダリング時間・ファイルサイズが大きく、MVP 検証に不向き |
| 動画尺 | 15〜20秒（hero + ending のみ） | scene 数を最小にしてレンダリング時間を短縮。品質検証が速い |
| BGM | なし | 音声同期は複雑。MVP では映像のみで価値検証 |
| アニメーション | シンプルな fade-in / slide-in のみ | ParticleField・RadarChart 等の重いコンポーネントは後フェーズ |
| テンプレート | 固定 1 種類 | テンプレート選択 UI は後回し |
| queue | AsyncAdapter（Sidekiq は後フェーズ） | インフラ変更なしで動作確認できる |
| リトライ | 手動（failed 状態を pending にリセット） | 自動 retry は render 環境が安定してから追加 |

### MVP 成功基準

1. `GenerateRecapMovieJob` が `Singing::RecapMovieRenderer.call(movie)` を呼べる
2. `bemystyle-reel/scripts/render_recap_movie.js` が JSON を受け取り mp4 を出力できる
3. 生成された mp4 が `SingingGeneratedRecapMovie#video_file` に attach される
4. ステータスが `completed` になり、S3 の Presigned URL でブラウザ再生できる

---

## 13. 将来スケール戦略

| フェーズ | 内容 |
|---------|------|
| **Phase 4-B（本実装）** | 案B（EC2 + Node + Remotion）で MVP 動作確認 |
| **Phase 5（安定化）** | Sidekiq 導入。`recap_movie` 専用 queue。AsyncAdapter のリスクを解消 |
| **Phase 6（UX改善）** | ActionCable / Hotwire Turbo Streams で生成完了通知をリアルタイムに表示 |
| **Phase 7（スケール）** | EC2 の render 専用インスタンスを分離（render 負荷を Web インスタンスから切り離す） |
| **Phase 8（クラウド）** | AWS Lambda 移行または ECS Fargate でオートスケール。Remotion Lambda パッケージを検討 |

---

## 14. 残課題

| # | 課題 | 優先度 |
|---|------|-------|
| 1 | EC2 に Node.js / ffmpeg / Chromium をインストールし、render 時間を実測する | 高 |
| 2 | `bemystyle-reel/` のパスを `ENV["BEMYSTYLE_REEL_PATH"]` で設定可能にする（ハードコード禁止） | 高 |
| 3 | `scripts/render_recap_movie.ts` のビルド（ts → js トランスパイル）方法を決める | 高 |
| 4 | `RecapMovie` Composition を `bemystyle-reel/src/Root.tsx` に追加する | 高 |
| 5 | MVP シーン（hero + ending）の Remotion コンポーネントを実装する | 高 |
| 6 | `Singing::RecapMovieRenderer` Service Object を実装する | 高 |
| 7 | render タイムアウト値を EC2 実測値から決定する（暫定 300秒） | 中 |
| 8 | Sidekiq 導入タイミングを確定する（本実装前か後か） | 中 |
| 9 | S3 Presigned URL の有効期限設計（Share UI と連携） | 中 |
| 10 | `tmp/generated_recap_movies/` の `.gitignore` 追記 | 低 |
| 11 | render 完了通知（ActionCable / Push 通知）の設計 | 低 |
| 12 | 生成動画の個人情報保護対応（expires_at 設計は完了済み。S3 ライフサイクルと連携確認） | 低 |

---

## 関連ドキュメント

- [Remotion Handoff（JSON仕様）](handover/achievement_recap_movie_remotion_handoff.md)
- [Cleanup Scheduler 設計](handover/recap_movie_cleanup_scheduler.md)
- [アーキテクチャ概要](handover/architecture.md)
