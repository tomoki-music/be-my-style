# デプロイルール

## 大原則

**main push = GitHub Actions トリガー = 即本番デプロイ。**
feature ブランチ → PR → レビュー → main マージ のフロー以外は禁止。

---

## デプロイ前確認（必須 4 点セット）

```bash
# 1. 不要ファイル・マーカー混入チェック
git diff --check

# 2. Rails 起動確認
DISABLE_SPRING=1 bundle exec rails runner 'puts "boot ok"'

# 3. アセットプリコンパイル（CSS / JS 変更時は必須）
RAILS_ENV=production bundle exec rails assets:precompile

# 4. テスト
bundle exec rspec
```

CSS / JS / 画像に変更がない場合でも 1 と 2 は**常に必須**。

---

## assets:precompile の注意点

- CSS / JS / 画像を変更した場合は必ず実行する。
- `public/assets/` はコミットしない（`.gitignore` で除外済み前提）。
- 本番サーバー上で実行してから Puma を再起動する。

```bash
# 本番サーバー上
RAILS_ENV=production bundle exec rails assets:precompile
sudo systemctl restart puma
```

---

## Puma 再起動確認

```bash
# 再起動
sudo systemctl restart puma

# 起動状態確認
sudo systemctl status puma

# 起動直後のログ確認（エラーがないか）
sudo journalctl -u puma -n 50 --no-pager
```

Puma 再起動後は必ずログを確認し、`started puma` が出ていることを確認する。

---

## 本番 DB マイグレーション

```bash
# マイグレーション実行
RAILS_ENV=production bundle exec rails db:migrate

# マイグレーション状態確認
RAILS_ENV=production bundle exec rails db:migrate:status
```

**危険ポイント:**
- カラム削除・型変更は既存データへの影響を事前確認する。
- 大テーブルへの `ADD COLUMN` はロックに注意（必要なら `pt-online-schema-change` 等を検討）。
- マイグレーション実行前にバックアップを確認する。

---

## ロールバック手順

```bash
# 直前のコミットに戻す（本番サーバー上）
git log --oneline -5
git checkout <commit-hash>
sudo systemctl restart puma

# DB マイグレーションを 1 つ戻す
RAILS_ENV=production bundle exec rails db:rollback STEP=1
```

**注意:**
- ロールバックは必ずユーザーに確認してから実行する。
- DB ロールバックはデータ損失リスクがある。慎重に判断する。
- コードとマイグレーションのバージョンを合わせることを忘れない。

---

## 本番変更時の全体注意事項

- 本番サーバーへの SSH・コマンド実行は**事前確認必須**。
- systemd サービスの stop / restart は確認なしに実行しない。
- 環境変数の変更（systemd Unit ファイル）は `daemon-reload` + Puma 再起動が必要。
- Stripe / OpenAI / S3 の設定変更は特に慎重に扱う。
