# Git 運用ルール

## 絶対禁止事項

### main への直接作業・直接 push は禁止

```
❌ git checkout main && git commit ...
❌ git push origin main
❌ git push origin HEAD:main
```

**理由:** main push = GitHub Actions が即トリガー = 即本番デプロイ。
ミスが直接ユーザー影響・本番障害につながる。

### feature ブランチ必須

すべての変更は feature ブランチで行い、PR → レビュー → マージ のフローを踏む。

```bash
# 正しいフロー
git checkout main && git pull origin main
git checkout -b feature/fix-ai-comment-timeout
# ... 作業 ...
git push origin feature/fix-ai-comment-timeout
# PR 作成 → レビュー → main マージ
```

ブランチ命名規則:

| プレフィックス | 用途 |
|--------------|------|
| `feature/` | 新機能・改善 |
| `fix/` | バグ修正 |
| `hotfix/` | 本番緊急修正 |
| `chore/` | 設定・依存変更 |

---

## マージ前確認コマンド（必須）

```bash
# 1. 不要なマーカー・ホワイトスペースがないか
git diff --check

# 2. コミット対象の差分を目視確認
git diff --staged

# 3. 意図しないファイルが含まれていないか
git status

# 4. public/assets が含まれていないか確認
git diff --staged --name-only | grep "public/assets"
# → 何も出なければ OK
```

---

## public/assets commit 禁止

```
❌ git add public/assets/
❌ git add -A  （public/assets が含まれる危険があるため非推奨）
```

- `public/assets/` はデプロイ時に `rails assets:precompile` で生成する。
- `.gitignore` で除外済みであることを前提とするが、毎回 `git diff --staged --name-only` で確認する。

---

## その他 Git ルール

- `git add -A` / `git add .` は使わない。ファイル名を明示して add する。
- `git push --force` は禁止。`--force-with-lease` も要確認。
- `git reset --hard` は実行前にユーザー確認必須。
- `git commit --amend` は push 済みコミットには使わない。
- マージコミットが混入する場合は `git rebase` を検討する。

---

## コミットメッセージ規則

```
<type>: <summary>

<body (任意)>
```

type 例: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`

```bash
# 例
git commit -m "fix: AI コメント生成で空文字 API キーを正しく検出する"
git commit -m "feat: 歌声診断バンドタイプを追加"
```
