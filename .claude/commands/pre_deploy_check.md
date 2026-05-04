# デプロイ前チェックコマンド集

デプロイ前に必ず実行するコマンドと確認ポイント。

---

## 1. Git 差分チェック

```bash
# 不要なマーカー・ホワイトスペースがないか
git diff --check

# コミット対象ファイルの確認
git diff --staged --name-only

# public/assets が含まれていないか
git diff --staged --name-only | grep "public/assets"
# → 何も出力されなければ OK
```

**確認ポイント:**
- `git diff --check` がエラーを出さないこと
- `public/assets/` がステージに含まれていないこと
- `config/credentials.yml.enc` / `config/master.key` / `.env` が含まれていないこと

**危険ポイント:**
- `credentials.yml.enc` が差分にある場合は即停止してユーザーに確認する
- `master.key` が追跡されている場合は `.gitignore` を見直す

---

## 2. Rails 起動確認

```bash
DISABLE_SPRING=1 bundle exec rails runner 'puts "boot ok"'
```

**確認ポイント:**
- `boot ok` が出力されること
- `LoadError` / `NameError` が出ていないこと

**危険ポイント:**
- `Cannot load such file` → 依存 gem や require 漏れ
- `NoMethodError` → メソッドの定義場所を確認

---

## 3. アセットプリコンパイル（CSS / JS 変更時）

```bash
RAILS_ENV=production bundle exec rails assets:precompile
```

**確認ポイント:**
- エラーなく完了すること
- `public/assets/` にファイルが生成されること（コミットは不要）

**危険ポイント:**
- SCSS の `@import` 参照ミスはここで検出される
- JavaScript の構文エラーもここで発覚することがある

---

## 4. テスト実行

```bash
# 全テスト
bundle exec rspec

# 変更に関連するテストのみ（高速確認）
bundle exec rspec spec/services/singing_diagnoses/
bundle exec rspec spec/jobs/singing_diagnoses/
bundle exec rspec spec/helpers/singing/
```

**確認ポイント:**
- 全テストが通過すること
- 変更ファイルに対応する spec が存在すること

**危険ポイント:**
- テストが通過しても機能正しさは保証されない。手動確認も必要。
- `pending` テストが増えていないか確認する

---

## 5. マイグレーション確認（migration 追加時）

```bash
# マイグレーション状態確認
RAILS_ENV=production bundle exec rails db:migrate:status

# ローカルで dry-run（本番には実行しない）
bundle exec rails db:migrate:status
```

**確認ポイント:**
- `down` になっている未適用 migration がないこと
- カラム削除・型変更がある場合はデータ影響を確認する

---

## 全確認完了チェックリスト

- [ ] `git diff --check` エラーなし
- [ ] `public/assets` がコミットに含まれていない
- [ ] `credentials` / `master.key` / `.env` がコミットに含まれていない
- [ ] `rails runner 'puts "boot ok"'` 成功
- [ ] `assets:precompile` エラーなし（CSS/JS変更時）
- [ ] `bundle exec rspec` 全通過
- [ ] migration 状態確認済み（migration変更時）
