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

## 自動デプロイ（GitHub Actions）の順序と失敗時の再実行

`.github/workflows/rails.yml`（main push / 手動実行）が本番サーバーで次の順に実行する。同時に2つは動かない（Actions の `concurrency` とサーバー上の `flock`）。

| 順 | 処理 | 実行条件 | 失敗したとき |
|---|---|---|---|
| 1 | `git fetch` → `git reset --hard origin/main`（ワークフロー内） | 毎回 | 以降は実行しない |
| 2 | 以降は `script/deploy/production_deploy.sh`（更新後のコード） | 毎回 | — |
| 3 | 変更判定: **最後に全工程が成功したコミット**からの差分（＋ reset 前の HEAD からの差分） | 毎回 | 記録が無い・読めない・差分が取れない → すべて変更ありとして扱う |
| 4 | `bundle check`（失敗時 `bundle install`） | 毎回 | 中断。Puma は再起動しない |
| 5 | `yarn install --frozen-lockfile` | package.json/yarn.lock の変更・node_modules が無い | 同上 |
| 6 | `assets:precompile` | アセット関連の変更、コンパイル結果が無い、このコミットでの成功記録が無い | 中断。DB は変更しない。既存アセットは残る |
| 7 | `db:migrate db:abort_if_pending_migrations db:version` | **毎回**（未適用が無ければ何もしない） | 中断。Puma は再起動しない |
| 8 | `systemctl restart puma` → active になるまで待つ | 毎回 | 中断 |
| 9 | Puma の unix ソケットへ `GET /`（2xx/3xx）→ 応答中の `application-*.css` が 200 | 毎回 | 中断（CSS が無い場合は次回 precompile をやり直す） |
| 10 | singing-analyzer の pip install / 再起動 / `/health` | singing_analyzer の変更 | 中断 |
| 11 | 成功の記録 `~/.be-my-style-deploy/last_successful_commit` を更新 | 1〜10 がすべて成功 | — |

- **途中で失敗したら、原因を直して同じワークフローを「Re-run」すればよい。** 成功の記録は更新されていないため、再実行でも同じ差分で必要な処理をやり直す（migrate は残りだけ、precompile は済んでいれば省略）。
- 失敗した段階は Actions のログの `::error::deploy failed at step '...'` で分かる。Puma を再起動する前に失敗した場合、動作中の Puma は旧コードのまま（ディスク上のコードは新しい）。**この状態で夜間自動停止（JST 2:00）からの起動などで Puma が再起動すると、新コードが未マイグレーションの DB で動く**ため、その前に再実行する。
- 記録が信用できないとき（手動作業の後など）は、手動実行で `force_full_deploy: true` を選ぶとすべて実行する。記録ファイルはリポジトリの外（`~/.be-my-style-deploy/`）にあり、`git reset` では消えない。
- デプロイするのは常に実行時点の `origin/main`。古いコミットで起動した実行を Re-run しても、main より古いコードには戻らない(起動元と異なる場合はログに `::notice::` を出す)。
- **この仕組みを導入する前(旧ワークフロー)の実行は Re-run しない。** Re-run は起動当時のワークフロー定義で動くため、旧ロジック(排他なし・差分が空なら migrate を省略)が最新コードに対して実行される。やり直したいときは Actions の「Run workflow」(main)で新しく実行する。
- 手動実行は main の定義だけが動く(ジョブに `github.ref == 'refs/heads/main'` の条件)。
- 秘密情報をログに出さないため、失敗時も Puma のログ本文は出さない。サーバー上で `sudo journalctl -u puma -n 100` と `log/puma.stderr.log` を確認する（要ユーザー確認）。
- 検証: `spec/deploy/production_deploy_script_spec.rb`（各段階で失敗させて再実行。本番には接続しない）。

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

## ローカル開発でのスキーマ変更後の実機確認手順（必須）

**背景:** マイグレーションを追加した機能で、長時間起動中のローカル Puma
(`bin/rails server` / `puma -C config/puma.rb` 等) が古いスキーマキャッシュを
保持したまま新カラムを認識できず、`ActiveModel::MissingAttributeError` が
実機確認時に複数回発生した(2026-07-18 チャット返信機能, 2026-07-19 同機能の追加調査)。
`rails runner` や `rails db:migrate` はその都度新しいプロセスを起動するため
問題を再現せず、**起動し続けている Puma プロセスだけ**が古いスキーマを持ち続ける
点が見落としやすい。

マイグレーションを含む機能をローカルで実機確認する前は、必ず以下を行う。

```bash
# 1. マイグレーション適用
bundle exec rails db:migrate

# 2. Spring 停止 + Puma 再起動 (tmp_restart プラグイン経由)
bin/spring stop
touch tmp/restart.txt

# 3. 新カラムをアプリ側(スキーマキャッシュ)が認識しているか確認
bundle exec rails runner 'puts ChatMessage.column_names.include?("reply_to_chat_message_id")'
```

`touch tmp/restart.txt` は `config/puma.rb` に `plugin :tmp_restart` が
設定されている前提(本アプリは設定済み)。Puma ワーカーの再起動は
`ps aux | grep puma` でワーカー PID が touch 前後で変わっていることを
確認すると確実。マスタープロセスの PID は再起動しても変わらない。

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

- コードを戻すと、そのコードに無い権限チェック・機能は効かなくなる。機能ごとのリリースノートで、切り戻し時に失われる制限を確認してから判断する。
- 手動で `git checkout` した後に次の自動デプロイが走ると、`origin/main` へ戻る（差分判定は checkout したコミットからの差分も含めるため、必要な処理は実行される）。
