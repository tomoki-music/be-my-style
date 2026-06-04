# Branch Safety Checklist

Phase31-D で main への誤コミットが発生した（push 前に検出・復旧）。

このドキュメントは同種のミスを再発させないための手順と判断基準を明文化する。

Agent・開発者ともに Singing 領域の作業開始前に必ず読むこと。

---

## 1. 作業開始前チェック

```bash
# 現在のブランチを確認する
git branch --show-current

# 作業ツリーの状態を確認する
git status

# リモートの最新状態を取得する
git fetch origin
```

`git branch --show-current` が `main` を返した場合は **必ず feature ブランチを作成してから作業を開始する**。

```bash
git checkout main
git pull --ff-only origin main
git checkout -b feature/<phase-name>
```

`git pull --ff-only` は fast-forward のみ許可する。予期しないマージコミットを防ぐためこの形式を使う。

---

## 2. コミット前チェック

コミットする前に以下を必ず確認する。

```bash
# ブランチが feature/* であることを確認する
git branch --show-current

# 作業ツリーの状態を確認する
git status

# ホワイトスペースエラー・マーカー混入がないことを確認する
git diff --check

# コミット対象の差分を目視確認する
git diff --staged
```

**`git branch --show-current` が `main` を返した場合はコミットしない。**

feature ブランチに切り替えてから `git add` しなおすこと。

---

## 3. push 前チェック

```bash
# ブランチが feature/* であることを確認する
git branch --show-current

# コミット内容を確認する
git log --oneline -5

# 意図しないファイルが含まれていないかを確認する
git status

# public/assets が含まれていないことを確認する
git diff --staged --name-only | grep "public/assets"
# → 何も出なければ OK
```

push 先は必ず `feature/<phase-name>` ブランチ。

```bash
# 正しい push
git push origin feature/<phase-name>

# これは禁止
git push origin main
```

---

## 4. main に誤コミットした場合の復旧手順

push 前であれば以下で復旧できる。

### 手順

```bash
# 1. feature ブランチを現在の main（誤コミット含む）に向けて作成する
git branch feature/<phase-name>

# 2. main に切り替える
git checkout main

# 3. origin/main を最新に取得する
git fetch origin

# 4. main を origin/main に強制リセットする（誤コミットが消える）
git reset --hard origin/main

# 5. feature ブランチに切り替えて作業を続ける
git checkout feature/<phase-name>
```

または feature ブランチが既に作成済みで別のコミットを指している場合は `git branch -f` で上書きする。

```bash
# feature ブランチを main の誤コミット位置に強制移動する
git branch -f feature/<phase-name> main

git checkout main
git reset --hard origin/main
git checkout feature/<phase-name>
```

### 注意

```text
git reset --hard を実行する前に、必ず feature ブランチ側にコミットが残っていることを確認する。
feature ブランチが誤コミットを指していない状態でリセットすると、作業内容が失われる。
```

復旧後は `git log --oneline -5` でブランチとコミットの状態を確認すること。

---

## 5. 禁止事項

```text
main へ直接コミットしない
main から直接 push しない
git push --force を使わない（--force-with-lease も要確認）
git reset --hard をユーザー確認なしに本番影響のある操作に使わない
secret / credentials / Stripe 設定を不用意に変更しない
public/assets を意図せずコミットしない
```

---

## 6. PR 作成時の形式

```text
feature/<phase-name> → main
```

PR タイトルは短く（70 文字以内）。本文に変更内容・確認コマンドの実行結果を記載する。

---

## 7. ブランチ命名規則

| プレフィックス | 用途 |
|--------------|------|
| `feature/` | 新機能・改善 |
| `fix/` | バグ修正 |
| `hotfix/` | 本番緊急修正 |
| `chore/` | 設定・依存変更 |
| `docs/` | ドキュメントのみ（任意） |

---

## 8. Phase31-D での誤コミット事例

### 発生内容

`git checkout -b feature/phase31-d-singing-nav-guidelines-docs` で branch を作成したつもりが、git 状態の都合で main に残留したまま commit が実行された。

### 検出

`git commit` 後の出力が `[main <hash>]` となっていたため即検出。

### 復旧

```bash
git branch -f feature/phase31-d-singing-nav-guidelines-docs main
git reset --hard origin/main
git checkout feature/phase31-d-singing-nav-guidelines-docs
git push origin feature/phase31-d-singing-nav-guidelines-docs
```

コミット内容は feature ブランチに保持されたまま main を戻せた。

### 教訓

```text
git checkout -b 直後に必ず git branch --show-current で確認する。
add / commit の直前にも git branch --show-current を実行する。
```

---

## 9. 関連ドキュメント

```text
CLAUDE.md                              ← 絶対ルール（ブランチ運用・push 禁止・秘密情報）
docs/handover/singing_index.md        ← Singing 全体 index
.claude/rules/git_rules.md            ← Git 運用ルール詳細
```
