# デプロイ手順

## 前提

- **main push = 即本番デプロイ。**
- feature ブランチ → PR → レビュー → main マージ のフローを必ず守る。
- 本番サーバーへの直接 SSH 操作は事前確認必須。

## デプロイフロー

```
1. feature ブランチで開発・テスト
2. ローカルでデプロイ前確認コマンドを実行
3. PR 作成 → レビュー
4. main マージ
5. 本番サーバーで git pull + 必要な後処理
```

## デプロイ前確認コマンド（必須）

```bash
# ホワイトスペース・マーカー混入チェック
git diff --check

# Rails 起動確認
DISABLE_SPRING=1 bundle exec rails runner 'puts "boot ok"'

# アセットプリコンパイル（CSS/JS変更時）
RAILS_ENV=production bundle exec rails assets:precompile

# テスト実行
bundle exec rspec
```

## 本番サーバーでの後処理

```bash
# コード取得
git pull origin main

# gem 更新 (Gemfile 変更時)
bundle install --without development test

# DB マイグレーション (migration 追加時)
RAILS_ENV=production bundle exec rails db:migrate

# アセット (CSS/JS 変更時)
RAILS_ENV=production bundle exec rails assets:precompile

# Puma 再起動
sudo systemctl restart puma

# Nginx 再読み込み (設定変更時のみ)
sudo systemctl reload nginx
```

## 環境変数の確認（本番）

```bash
# systemd で設定された環境変数一覧
sudo systemctl show puma --property=Environment

# 特定の変数が空文字でないか確認
sudo journalctl -u puma -n 50 --no-pager
```

**注意:** systemd の環境変数変更は Puma 再起動後に反映される。

## ログ確認

```bash
# Rails アプリログ (Puma)
sudo journalctl -u puma -n 100 --no-pager
sudo journalctl -u puma -f   # リアルタイム

# Nginx エラーログ
sudo tail -n 100 /var/log/nginx/error.log

# Nginx アクセスログ
sudo tail -n 100 /var/log/nginx/access.log
```

## アセットに関する注意

- `public/assets/` はコミットしない。
- `.gitignore` でトラッキングを除外済みであることを確認する。
- デプロイ時に `assets:precompile` を実行してサーバー上で生成する。

## ロールバック手順

```bash
# 直前のコミットに戻す (本番サーバー上)
git log --oneline -5  # コミットハッシュ確認
git checkout <commit-hash>
sudo systemctl restart puma

# マイグレーションを戻す場合
RAILS_ENV=production bundle exec rails db:rollback STEP=1
```

**重要:** ロールバック実行前にユーザーへ確認する。DB ロールバックはデータ損失リスクがある。
