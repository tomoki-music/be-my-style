# Recap Movie E2E 確認手順

## 概要

Rails → Remotion → mp4 → ActiveStorage attach の end-to-end を手元で検証するための手順書。

---

## 前提条件

### 1. bemystyle-reel のパス確認

```bash
# Rails アプリから見たデフォルトパス
ls ../bemystyle-reel/scripts/render_recap_movie.js
```

デフォルトは `Rails.root.join("..", "bemystyle-reel")` を参照する。
別パスを使う場合は環境変数で上書きする：

```bash
export BEMYSTYLE_REEL_PATH=/absolute/path/to/bemystyle-reel
```

### 2. bemystyle-reel の依存インストール確認

```bash
cd ../bemystyle-reel
node --version   # v18+ 推奨
npm install
```

### 3. Chromium / ffmpeg の確認

Remotion は内部で Chromium と ffmpeg を使用する。

```bash
# Chromium 確認（Remotion が自動ダウンロードする場合もあり）
npx remotion install chromium

# ffmpeg 確認
ffmpeg -version
```

---

## ローカル E2E 手順

### Step 1: rails runner でジョブを直接実行

```bash
cd /path/to/be-my-style

DISABLE_SPRING=1 bundle exec rails runner '
  movie = SingingGeneratedRecapMovie.where(status: :pending).last
  puts "movie_id=#{movie&.id} status=#{movie&.status}"
  GenerateRecapMovieJob.perform_now(movie.id) if movie
  movie.reload
  puts "after: status=#{movie.status} error=#{movie.error_message}"
'
```

### Step 2: レコードをその場で作成してテスト

```bash
DISABLE_SPRING=1 bundle exec rails runner '
  customer = Customer.first
  movie = SingingGeneratedRecapMovie.create!(
    customer: customer,
    year: Date.today.year,
    status: :pending
  )
  puts "created movie_id=#{movie.id}"
  GenerateRecapMovieJob.perform_now(movie.id)
  movie.reload
  puts "status=#{movie.status}"
  puts "error=#{movie.error_message}" if movie.failed?
  puts "attached=#{movie.video_file.attached?}" if movie.completed?
'
```

### Step 3: Renderer を直接呼ぶ（Job 経由なし）

```bash
DISABLE_SPRING=1 bundle exec rails runner '
  movie = SingingGeneratedRecapMovie.find(<MOVIE_ID>)
  result = Singing::RecapMovieRenderer.new(movie).call
  puts "result=#{result}"
  movie.reload
  puts "status=#{movie.status}"
  puts "error=#{movie.error_message}"
'
```

---

## 確認ポイント

### status=completed 確認

```ruby
movie = SingingGeneratedRecapMovie.find(<id>)
puts movie.status       # => "completed"
puts movie.error_message # => nil
```

### video_file attach 確認

```ruby
puts movie.video_file.attached?   # => true
puts movie.video_file.filename    # => "recap_2025.mp4"
puts movie.video_file.byte_size   # => 非ゼロ
```

### S3 upload 確認

```ruby
puts movie.video_file.service_url  # S3 の署名付き URL が返る
# ブラウザで開いて mp4 が再生できることを確認
```

ActiveStorage の storage 設定:

```bash
# development は通常 :local
grep -A5 "default:" config/storage.yml
```

### tmp cleanup 確認

```bash
ls tmp/generated_recap_movies/
# 正常完了後は空 (Dir.mktmpdir ブロックが終了時に削除する)
```

---

## ログ確認

Renderer は以下のログを出力する：

```
[RecapMovieRenderer] start movie_id=X year=2025
[RecapMovieRenderer] props exported movie_id=X path=/tmp/...
[RecapMovieRenderer] render command start movie_id=X script=... chdir=...
[RecapMovieRenderer] render command success movie_id=X elapsed=Xs
[RecapMovieRenderer] attach success movie_id=X
[RecapMovieRenderer] completed movie_id=X elapsed_total=Xs
```

失敗時：

```
[RecapMovieRenderer] render command failed movie_id=X exit_status=1 stderr=...
[RecapMovieRenderer] fail_with movie_id=X message=...
```

timeout 時：

```
[RecapMovieRenderer] render timeout movie_id=X timeout=150s
```

---

## よくある失敗と対処

### Chromium が見つからない

```
Error: Could not find Chrome
```

対処：

```bash
cd ../bemystyle-reel
npx remotion install chromium
```

または `PUPPETEER_EXECUTABLE_PATH` / `CHROME_PATH` で指定する。

### ffmpeg が見つからない

```
Error: ffmpeg not found
```

対処（macOS）：

```bash
brew install ffmpeg
```

### npm install 未実行 / node_modules なし

```
Error: Cannot find module '@remotion/renderer'
```

対処：

```bash
cd ../bemystyle-reel && npm install
```

### render timeout (150秒)

大きな Composition や遅いマシンで発生する。

確認事項：
- Chromium が起動できているか（`[RecapMovieRenderer] render command start` の後でタイムアウトしていれば Chromium 起動問題）
- `RENDER_TIMEOUT_SEC` を一時的に引き上げてテスト

### BEMYSTYLE_REEL_PATH not found

```
BEMYSTYLE_REEL_PATH not found: /path/to/bemystyle-reel
```

対処：

```bash
export BEMYSTYLE_REEL_PATH=/absolute/path/to/bemystyle-reel
```

### render script not found

```
render script not found: /path/to/scripts/render_recap_movie.js
```

対処：

```bash
ls ../bemystyle-reel/scripts/render_recap_movie.js
# なければ bemystyle-reel のセットアップが必要
```

---

## 環境変数一覧

| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `BEMYSTYLE_REEL_PATH` | `Rails.root/../bemystyle-reel` | Remotion プロジェクトルート |
| `RECAP_MOVIE_RENDER_SCRIPT` | `scripts/render_recap_movie.js` | レンダースクリプト（BEMYSTYLE_REEL_PATH からの相対パス） |
| `RECAP_MOVIE_TMP_ROOT` | `Rails.root/tmp/generated_recap_movies` | 一時ファイル置き場 |

---

## smoke test コマンド

```bash
# 差分チェック
git diff --check

# spec 単体
DISABLE_SPRING=1 ~/.rbenv/shims/bundle exec rspec spec/services/singing/recap_movie_renderer_spec.rb

# smoke: rails 起動確認
DISABLE_SPRING=1 bundle exec rails runner 'puts "boot ok"'
```
