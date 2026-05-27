# Phase 10-N-2: Remotion Project Deployment Check

作成日: 2026-05-27  
ブランチ: `feature/recap-movie-remotion-deployment-check`

---

## 現在の失敗原因

本番1件生成テストで runner は安全に動作したが、RecapMovieRenderer が以下のエラーで失敗した:

```
BEMYSTYLE_REEL_PATH not found: /home/ec2-user/bemystyle-reel
```

**根本原因:** 本番 EC2 に Remotion プロジェクト `bemystyle-reel` が配置されていない。

---

## Rails 側の参照パス

**ファイル:** `app/services/singing/recap_movie_renderer.rb:171`

```ruby
@remotion_root ||= ENV.fetch("BEMYSTYLE_REEL_PATH", Rails.root.join("..", "bemystyle-reel").to_s)
```

| 項目 | 値 |
|------|-----|
| デフォルトパス | `Rails.root.join("..", "bemystyle-reel")` = `/home/ec2-user/be-my-style/../bemystyle-reel` = `/home/ec2-user/bemystyle-reel` |
| ENV override | `BEMYSTYLE_REEL_PATH` を設定すれば任意パスに変更可能 |
| render script | `RECAP_MOVIE_RENDER_SCRIPT`（デフォルト: `scripts/render_recap_movie.js`） |

**Validate 処理（同:78-86行）:**

1. `Dir.exist?(remotion_root)` → なければ `BEMYSTYLE_REEL_PATH not found: ...` で raise
2. `File.exist?(absolute_script_path)` → なければ `render script not found: ...` で raise

---

## ローカル Remotion repo の確認結果

**所在:** `/Users/tomokiimaizumi/bemystyle-reel`（Rails repo の sibling directory として存在）

### git 状態

```
origin: https://github.com/tomoki-music/bemystyle-reel.git
branch: main
状態: main より 1 commit ahead（push 待ち）
uncommitted: なし（working tree clean）
```

### 必須ファイルの存在確認

| ファイル | 状態 |
|---------|------|
| `package.json` | ✅ 存在 |
| `src/Root.tsx` | ✅ 存在 |
| `src/compositions/RecapMovie.tsx` | ✅ 存在 |
| `scripts/render_recap_movie.js` | ✅ 存在 |
| `src/index.ts` | ✅ 存在 |
| `node_modules/` | ✅ ローカルに存在（commit されていない） |

### RecapMovie Composition スペック

| 項目 | 値 |
|------|-----|
| Composition ID | `RecapMovie` |
| 解像度 | `1080 × 1920`（縦型 9:16） |
| FPS | `30` |
| フレーム数 | `450 frames`（= 15秒） |
| render script | `@remotion/renderer` の `renderMedia` 使用 |

### package.json dependencies

```json
"@remotion/cli": "^4.0.0",
"@remotion/renderer": "^4.0.0",
"remotion": "^4.0.0",
"react": "^18.2.0"
```

---

## Rails repo との分離確認

`.gitignore`（L44-45）:

```
# Remotion video production (lives outside this repo at ../bemystyle-reel)
/reel/
```

- `bemystyle-reel/` は Rails repo の外（sibling directory）で管理されている
- Rails repo 内に Remotion 成果物は混入していない
- `node_modules` は bemystyle-reel repo の `.gitignore` で除外されている

---

## 本番配置前チェックリスト

- [ ] `bemystyle-reel` の main ブランチに未 push のコミットがある（1 commit ahead）→ 先に `git push` が必要
- [ ] 本番 EC2 で node / npm のバージョン確認（`node --version` / `npm --version`）
- [ ] 本番 EC2 のディスク空き容量確認（`df -h ~`）
- [ ] GitHub から clone できるか事前確認（public repo か、SSH キーが設定されているか）

---

## 本番配置手順案

### 案A: git clone（推奨）

```bash
# 本番 EC2 上で実行（まだ実行しない）
cd /home/ec2-user

# clone
git clone https://github.com/tomoki-music/bemystyle-reel.git bemystyle-reel

cd bemystyle-reel

# node_modules インストール（package-lock.json があるため npm ci を使う）
npm ci

# render script が存在するか確認
test -f scripts/render_recap_movie.js && echo "OK" || echo "MISSING"

# node で syntax チェック（実行はしない）
node --check scripts/render_recap_movie.js && echo "syntax OK"
```

### 案B: scp（非推奨）

理由:
- 差分管理しづらい
- `node_modules` の混入リスク（数百MB）
- 再現性が低い
- git 管理外になるため更新が手動になる

---

## ENV 設定案

### 方針1: runner 実行時に明示指定（追加設定なしで動作確認したい場合）

```bash
BEMYSTYLE_REEL_PATH=/home/ec2-user/bemystyle-reel \
RAILS_ENV=production \
./bin/run_pending_recap_movie_generation
```

runner スクリプトはそのまま使える。ENV は明示指定で上書きされる。

### 方針2: systemd drop-in に恒久設定（cron 運用に入ったら）

```ini
# /etc/systemd/system/puma.service.d/recap-movie.conf
[Service]
Environment=BEMYSTYLE_REEL_PATH=/home/ec2-user/bemystyle-reel
```

設定後は必ず:

```bash
sudo systemctl daemon-reload
sudo systemctl restart puma
sudo journalctl -u puma -n 30 --no-pager
```

---

## 本番での配置確認コマンド（配置後）

```bash
# ディレクトリ存在確認
ls -la /home/ec2-user/bemystyle-reel

# package.json 確認
test -f /home/ec2-user/bemystyle-reel/package.json && echo "package.json OK"

# render script 確認
test -f /home/ec2-user/bemystyle-reel/scripts/render_recap_movie.js && echo "render_script OK"

# node / npm バージョン確認
node --version && npm --version

# node_modules 確認
test -d /home/ec2-user/bemystyle-reel/node_modules && echo "node_modules OK"
```

---

## 再実行前の安全確認（dry-run）

```bash
# dry-run で pending movie を拾えるか確認（生成しない）
DRY_RUN=1 \
BEMYSTYLE_REEL_PATH=/home/ec2-user/bemystyle-reel \
RAILS_ENV=production \
./bin/run_pending_recap_movie_generation
```

dry-run で `picked pending movie_id=XXX` が出れば、runner・DB・ENV の接続は正常。

---

## やってはいけないこと

- 本番へ直接 scp でコピーしない（`node_modules` 混入・git 管理外になる）
- 本番で `npm install` ではなく `npm ci` を使う（`package-lock.json` で再現性保証）
- `node_modules` を commit しない
- Rails repo 内に `bemystyle-reel/` を入れない
- cron 登録は dry-run 確認後まで行わない
- credentials / .env を触らない
- `public/assets` を触らない
- Puma の再起動は必要最小限にとどめ、事前にユーザーへ確認する

---

## 次フェーズ候補

### Phase 10-N-3: Remotion Project Production Placement

1. bemystyle-reel の main を push（ローカルで 1 commit ahead になっているため）
2. 本番 EC2 で `git clone` + `npm ci`
3. dry-run 確認
4. 1件だけ再生成
5. Puma ログ確認

### Phase 10-O: Controlled Cron Activation

1. dry-run cron（生成しない）
2. 本実行 cron（低頻度・1回1件）
3. 監視体制確認
