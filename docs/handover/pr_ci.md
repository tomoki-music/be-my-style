# Pull Request CI

## 前提

- `.github/workflows/pr-ci.yml` は Pull Request を契機に実行される検証用 Workflow。
- 既存の `.github/workflows/rails.yml`(main push → EC2 本番デプロイ)とは完全に独立しており、本番デプロイ処理には一切関与しない。
- 現時点では GitHub の Branch protection に必須チェックとして登録していない(別タスクで実施予定)。

## 構成

| ジョブ | 役割 | Workflow全体への影響 |
|---|---|---|
| `Required checks` | 安定して成功する検証のみを実行 | 失敗するとWorkflow失敗 |
| `Full RSpec suite (informational)` | 全RSpecを実行し既存失敗を可視化 | `continue-on-error: true`(ジョブ単位)のため失敗してもWorkflowは失敗にならない |

## test環境はMySQLではなくsqlite3

`config/database.yml` の `test:` は `default` (`adapter: sqlite3`) を継承しており、development/productionのみ `mysql2` を使用する。そのため、PR CIでは **MySQLのservice containerを使用していない**。`bundle exec rails db:schema:load` のみでテストDBを準備する。

ただし `Gemfile` の `gem 'mysql2'` はグループ指定なしのため、`bundle install` 時に常にネイティブ拡張のビルドが発生する。CIでは `libmysqlclient-dev` をaptでインストールしてから `bundle install` している。

## test環境専用のCredentials

`config/environments/test.rb` や `config/initializers/devise.rb` などが起動時に即時 `Rails.application.credentials.gmail[:user_name]` を読むため、master keyが無い状態ではRailsがtest環境で起動できない。

本番の `config/master.key` / `config/credentials.yml.enc` は絶対に使用しない(CLAUDE.md参照)ため、Railsの環境別credentials機能で **test環境専用の新規ダミー認証情報** を用意している。

- `config/credentials/test.yml.enc`(暗号化された中身、コミット対象)
- `config/credentials/test.key`(復号キー、コミット対象。`.gitignore` から除外して明示的に追跡)

中身は `gmail: { user_name: ci-dummy@example.com, password: dummy-ci-password }` のみで、実在のメールアドレス・パスワードではない。`Rails.env == "test"` の場合、Railsは自動的にこのファイルを優先し、development/productionには一切影響しない。

このキーは本番Secretsとは無関係のため、Fork由来のPRでもGitHub Secretsなしで同じように動作する。

## Node.js / Yarn

- `@rails/webpacker 5.4.3` + `webpack 4` を使用しており、Node 17以降はOpenSSL3のデフォルト変更により `error:0308010C:digital envelope routines::unsupported` で失敗する。
- 開発機・本番でNode 16系を使用しているため、CIも `node-version: "16"` に合わせている。
- `bin/yarn install --frozen-lockfile` でlockfileを変更せずに依存関係を導入する。

## 必須RSpec対象の選定基準

全RSpecには既存失敗が40件以上あるため、`Required checks` では次を満たすspecのみを個別に列挙している(`.github/workflows/pr-ci.yml` の `Run stable RSpec subset` ステップ参照)。

- 直近の複数回実行で安定して成功する(ローカルで複数回確認済み)
- 外部サービスへ実通信しない(一部イベント関連specはGeocoder経由でGoogle Maps APIへ実通信するが、API未設定時のエラーをアプリ側が握りつぶす設計のため、テスト結果には影響しない。ネットワーク遮断環境ではこの点が新たな失敗要因になり得る)
- System spec/ブラウザ環境へ強く依存しない
- Model・Request・Service・Mailerの主要領域、および認証・コミュニティ・イベント参加・Markdown・SSRF対策(内部ホスト)を含む

対象を増減する場合は、Workflow内のコメントと本ドキュメントを合わせて更新する。

## 全RSpec参考ジョブ

- `bundle exec rspec --format documentation --format json --out tmp/full_rspec_results.json` で全件実行。
- rspec自体の終了コードでステップを失敗させず、`$GITHUB_OUTPUT` に保持してからSummary生成・artifactアップロードを行い、最後に改めてexit codeを反映させて「失敗した事実」を可視化する。
- 結果JSONは `full-rspec-output` artifact(7日保持)としてアップロードされる。
- System specがある(Chrome/ChromeDriverが必要)。ubuntu-latestランナーに標準搭載のGoogle Chrome + `webdrivers` gemの自動ダウンロードに任せており、専用のセットアップActionは追加していない。

## 将来の必須化

既存失敗が0件になったら、`full-suite-observation` ジョブから `continue-on-error: true` を外すだけで必須化できる構成にしてある。

Branch protectionへ必須チェックとして登録する際のチェック名:

- `Required checks`
- (将来) `Full RSpec suite (informational)`
