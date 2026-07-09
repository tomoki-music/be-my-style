# 本番サーバー移行Wiki: Amazon Linux 2 → Amazon Linux 2023

このドキュメントは、BeMyStyle本番環境をAmazon Linux 2(旧EC2)からAmazon Linux 2023(新EC2)へ移行した際の作業内容をまとめたものです。**このWikiだけで同じ環境をゼロから再構築できること**を目的としています。

> **表記について**: 実際のホスト名・IPアドレス・APIキー・パスワード等の機密情報は本ドキュメントに一切含めていません。`<...>` はプレースホルダーです。実際の値は `config/credentials.yml.enc` / systemd の Environment設定 / AWS Secrets等、正規の方法で管理してください。
>
> **未検証項目について**: 今回の移行作業で実際に手を動かして確認した項目(systemd構成・singing_analyzer・ffmpeg・トラブルシューティング等)は具体的な手順を記載しています。一方、今回のセッションでは直接確認していない項目(Nginx詳細設定・SSL/Certbot・Stripe・Gmail・GoogleMap等)は一般的な手順のみを示し、**「要確認」**として明示しています。次回移行時に実際の手順で埋めてください。

---

## 目次

1. [前提条件](#前提条件)
2. [AWS構成](#aws構成)
3. [EC2作成](#ec2作成)
4. [SecurityGroup](#securitygroup)
5. [Ruby](#ruby)
6. [Node](#node)
7. [Bundler](#bundler)
8. [master.key](#masterkey)
9. [credentials](#credentials)
10. [.env](#env)
11. [systemd](#systemd)
12. [Puma](#puma)
13. [Nginx](#nginx)
14. [Assets](#assets)
15. [Webpacker](#webpacker)
16. [S3](#s3)
17. [SSL](#ssl)
18. [Certbot](#certbot)
19. [Stripe](#stripe)
20. [Stripe Webhook](#stripe-webhook)
21. [singing_analyzer](#singing_analyzer)
22. [ffmpeg](#ffmpeg)
23. [uvicorn](#uvicorn)
24. [OpenAI](#openai)
25. [LINE](#line)
26. [ActiveStorage](#activestorage)
27. [Gmail](#gmail)
28. [GoogleMap](#googlemap)
29. [AIコメント](#aiコメント)
30. [動作確認チェックリスト](#動作確認チェックリスト)
31. [トラブルシューティング](#トラブルシューティング)
32. [今回ハマったポイント](#今回ハマったポイント)
33. [移行後チェックリスト](#移行後チェックリスト)

---

## 前提条件

- 旧サーバー: Amazon Linux 2 (EC2)
- 新サーバー: **Amazon Linux 2023** (EC2, x86_64)
- Rails 6.1.7.3 / Ruby 3.1.2 / MySQL(RDS) / Puma + Nginx / Redis(本番ジョブキュー) / S3 / Stripe / FastAPI(singing_analyzer)
- 作業には以下へのアクセスが必要:
  - 新EC2へのSSH鍵(`.pem`)
  - RDS接続情報
  - `config/master.key`(既存のものを新サーバーにコピー。**再生成不可**)
  - Stripe / OpenAI / LINE の本番APIキー
  - Route53 or DNS管理画面(SSL証明書切り替え用)
- **本移行の目的**: 旧EC2で稼働していたサービス一式を、新しいOSベース(AL2023)で完全に再現すること。

---

## AWS構成

- リージョン: `ap-northeast-1`(東京)
- EC2: アプリケーションサーバー(Rails + Puma + FastAPI singing_analyzer)
- RDS: MySQL(DB本体は移行対象外。エンドポイントの向き先のみ変更)
- S3: ActiveStorageの保存先(`amazon` service)。バケット自体は移行不要、EC2側のIAMロール/credentialsで接続する
- Route53 / DNS: ドメインのAレコードを新EC2のElastic IPへ向け直す

> 要確認: VPC/サブネット構成、Elastic IP付け替え手順、IAMロールの詳細は環境依存のため、実施時のAWSコンソール操作を追記してください。

---

## EC2作成

1. AMI: **Amazon Linux 2023** を選択(AL2ではない点に注意)
2. インスタンスタイプ: 旧EC2と同等以上を選択
3. キーペア: 新規 or 既存の `.pem` を指定
4. ストレージ: 旧EC2のディスク使用量を確認の上、同等以上を確保
5. Elastic IPを割り当て、DNSのAレコードを更新(切り替えタイミングは要調整)

初回ログイン確認:
```bash
ssh -i <keyfile>.pem ec2-user@<EC2のIP>
cat /etc/os-release
# → VERSION="2023" であることを確認
uname -m
# → x86_64 (静的バイナリ選定などアーキテクチャ依存の作業で必須)
```

---

## SecurityGroup

最低限必要なインバウンドルール:

| ポート | 用途 | Source |
|---|---|---|
| 22 | SSH | 管理者IPのみに制限(0.0.0.0/0は非推奨) |
| 80 | HTTP(Certbot認証・リダイレクト用) | 0.0.0.0/0 |
| 443 | HTTPS | 0.0.0.0/0 |

> **重要**: `singing_analyzer`(FastAPI, port 8000)は `127.0.0.1` のみでlistenする構成のため、SecurityGroupで外部公開する必要はなく、**すべきではありません**(インバウンドルールに8000番を追加しないこと)。RailsからはローカルループバックでHTTP通信します。

アウトバウンド: デフォルトall allowが一般的ですが、本番のVPC/NACL構成によっては特定の外部ホストへの到達性が制限されている場合があります(後述の[今回ハマったポイント](#今回ハマったポイント)を参照)。

---

## Ruby

旧EC2と同じバージョン管理方式(rbenv)を踏襲します。

```bash
# rbenv導入
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
source ~/.bashrc

# ビルド依存パッケージ(AL2023はdnf)
sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y openssl-devel readline-devel zlib-devel libyaml-devel

# Ruby 3.1.2 をインストール
rbenv install 3.1.2
rbenv global 3.1.2
ruby -v
```

> 要確認: AL2023特有のビルド依存パッケージ名は `dnf` ベースで一部AL2(yum)と異なる場合があります。`ruby-build` 実行時にエラーが出たパッケージを都度 `dnf install` してください。

---

## Node

Webpacker/JSアセットのビルドに必要です。

```bash
# NodeSourceリポジトリ経由(本番で確認済み: nodesource-nodejsリポジトリが有効化されている)
sudo dnf install -y nodejs
node -v
npm -v

# yarn
sudo npm install -g yarn
yarn -v
```

> 本番サーバーには `nodesource-nodejs` という dnf リポジトリが登録されていることを確認済みです(`dnf repolist` で確認可能)。同じ方法で新サーバーにも登録してください。

---

## Bundler

```bash
gem install bundler -v <Gemfile.lockのBUNDLED WITHバージョンに合わせる>
cd /home/ec2-user/be-my-style
bundle install --without development test --path vendor/bundle
```

`puma.service` の `ExecStart` は `/home/ec2-user/.rbenv/shims/bundle` を直接指定しているため、rbenvのshimが正しく生成されていることを確認してください:
```bash
rbenv rehash
ls -la /home/ec2-user/.rbenv/shims/bundle
```

---

## master.key

`config/master.key` は **リポジトリにコミットされていません**。旧EC2から安全な方法(SCP等、Slack/メール等の平文送信は厳禁)でコピーする必要があります。

```bash
# 旧EC2 → ローカル → 新EC2、または旧EC2 → 新EC2へ直接scp
scp -i <keyfile>.pem ec2-user@<旧EC2>:/home/ec2-user/be-my-style/config/master.key /tmp/master.key
scp -i <keyfile>.pem /tmp/master.key ec2-user@<新EC2>:/home/ec2-user/be-my-style/config/master.key
rm /tmp/master.key   # ローカルの一時ファイルは必ず削除
```

権限:
```bash
chmod 600 config/master.key
```

**CLAUDE.mdのルールに従い、AIエージェント(Claude Code含む)はこのファイルの内容を絶対に参照・編集してはいけません。**

---

## credentials

`config/credentials.yml.enc` は `master.key` で復号されます。今回の調査で判明した実際の格納内容(キー名のみ、値は不明):

| キー | 用途 | 備考 |
|---|---|---|
| `aws.access_key_id` | S3アクセス(ActiveStorage) | 20文字 |
| `aws.secret_access_key` | S3アクセス(ActiveStorage) | 40文字 |
| `openai_api_key` / `openai.api_key` | (未使用) | 今回の調査時点では未設定。OpenAIキーは**ENV経由**(後述)で管理されている |
| `singing_analyzer.diagnoses_url` / `singing_analyzer.api_key` | (未使用) | 今回の調査時点では未設定。**ENV経由**(`SINGING_ANALYZER_DIAGNOSES_URL`)で管理されている |

確認コマンド(値は表示せず、存在の有無・文字数のみ確認する):
```ruby
# rails runner で実行
def report(label, val)
  s = val.to_s
  puts "#{label}: present=#{!s.empty?} length=#{s.length}"
end
report("credentials.aws.access_key_id", Rails.application.credentials.dig(:aws, :access_key_id))
report("credentials.aws.secret_access_key", Rails.application.credentials.dig(:aws, :secret_access_key))
```

編集する場合(値を直接見ずに済ませたい場合はエディタ上で貼り付け→保存のみ行う):
```bash
EDITOR="vim" bin/rails credentials:edit
```

---

## .env

このアプリケーションの**本番環境では `.env` ファイルは使用していません**(今回の調査で `.env` への参照は本番サーバー上に見つかりませんでした)。環境変数はすべて `systemd` の `Environment=` ディレクティブ、またはRailsの `credentials.yml.enc` で管理されています。

- ローカル開発環境で `.env` を使う場合があっても、**本番の `systemd` 設定とは完全に別物**である点に注意してください。
- CLAUDE.mdのルールに従い、`.env` / `*.env.*` はAIエージェントが絶対に内容を参照・編集してはいけません。

---

## systemd

本番で稼働するsystemdサービスは2つです。

### 1. `puma.service`(Railsアプリ)

`/etc/systemd/system/puma.service`:
```ini
[Unit]
Description=Puma HTTP Server
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user/be-my-style
ExecStart=/bin/bash -lc 'RAILS_ENV=production /home/ec2-user/.rbenv/shims/bundle exec puma -C config/puma.rb'
Restart=always
RuntimeDirectory=puma
RuntimeDirectoryMode=0755

[Install]
WantedBy=multi-user.target
```

**重要**: このファイルには `[Service]` ブロックの環境変数(`Environment=`)を直接書き込まないでください。必ず `/etc/systemd/system/puma.service.d/` 配下のdrop-inファイルに分離します(理由は[今回ハマったポイント](#今回ハマったポイント)を参照)。

### 2. drop-in ディレクトリ: `/etc/systemd/system/puma.service.d/`

| ファイル | 内容(キー名のみ) |
|---|---|
| `env.conf` | `DB_HOST`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD` |
| `openai.conf` | `OPENAI_API_KEY` |
| `override.conf` | `LINE_CHANNEL_SECRET`, `LINE_CHANNEL_ACCESS_TOKEN` |
| `singing-analyzer.conf` | `SINGING_ANALYZER_DIAGNOSES_URL=http://127.0.0.1:8000/diagnoses` |
| `web-concurrency.conf` | `WEB_CONCURRENCY=<数値>` |

書式の注意点(**必読**、詳細は[今回ハマったポイント](#今回ハマったポイント)):
```ini
[Service]
Environment="OPENAI_API_KEY=sk-xxxx"
```
- ダブルクォートを使う場合は**開始と終了を必ず対にする**こと。片方だけだと `systemd-analyze verify` で `Invalid syntax, ignoring` となり、**エラーも出さずに静かに無視されます**。
- 値に `"` を含む場合は `\"` でエスケープする。
- クォートを使わない書式(`Environment=KEY=VALUE`)でも動作します(`SINGING_ANALYZER_DIAGNOSES_URL` 等はこの形式で問題なく動いています)。

### 3. `singing-analyzer.service`(FastAPI, 今回新規作成)

`/etc/systemd/system/singing-analyzer.service`:
```ini
[Unit]
Description=Singing Analyzer FastAPI Service
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user/be-my-style/singing_analyzer
ExecStart=/home/ec2-user/be-my-style/singing_analyzer/.venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000
Restart=always
RestartSec=3
Environment=PATH=/usr/local/bin:/usr/bin:/bin

[Install]
WantedBy=multi-user.target
```

### 共通コマンド

```bash
# 設定ファイルを追加/変更したら必ずdaemon-reload
sudo systemctl daemon-reload

# 構文チェック(実際にサービスを再起動せず検証できる)
sudo systemd-analyze verify puma.service
sudo systemd-analyze verify singing-analyzer.service

# 有効化(OS再起動後も自動起動)
sudo systemctl enable puma
sudo systemctl enable singing-analyzer

# 起動/再起動
sudo systemctl restart puma
sudo systemctl restart singing-analyzer

# 状態確認
sudo systemctl status puma --no-pager
sudo systemctl status singing-analyzer --no-pager
sudo systemctl is-enabled puma singing-analyzer
sudo systemctl is-active puma singing-analyzer
```

---

## Puma

- バージョン: 3.12.6(旧EC2から変更なし)
- 設定ファイル: `config/puma.rb`(リポジトリ内、通常は変更不要)
- 起動モード: クラスターモード(`WEB_CONCURRENCY` で worker数を制御)
- `RAILS_ENV=production` は `puma.service` の `ExecStart` 内で明示的に指定(drop-inのEnvironmentではない点に注意。`bash -lc 'RAILS_ENV=production ...'` の形)

再起動後は必ずログを確認する:
```bash
sudo journalctl -u puma -n 50 --no-pager
# "Started puma.service" と "Puma starting in cluster mode..." が出ていること
# ERROR / FATAL が出ていないこと
```

---

## Nginx

> 要確認: 今回のセッションでは Nginx の詳細設定(`server` ブロック、`proxy_pass` 設定、リダイレクト設定等)を直接確認していません。以下は一般的な構成の目安です。実際の `/etc/nginx/conf.d/*.conf` の内容を旧EC2から移植し、このセクションを更新してください。

一般的な構成の要点:
- `proxy_pass` は Puma の Unix socket(`unix:///run/puma/puma.sock`、`puma.service` の `RuntimeDirectory=puma` に対応)を指す
- `client_max_body_size` は歌唱診断の音声ファイルアップロードを考慮し、十分な大きさを設定する(旧EC2の設定値を確認)
- SSL証明書のパスはCertbotが自動生成する `/etc/letsencrypt/live/<ドメイン>/` を参照

```bash
sudo dnf install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx

# 設定反映
sudo nginx -t   # 構文チェック
sudo systemctl reload nginx
```

---

## Assets

CSS/JS変更時は必ずプリコンパイルします(`public/assets/` はコミットしないため、サーバー上で生成が必要):

```bash
cd /home/ec2-user/be-my-style
RAILS_ENV=production bundle exec rails assets:precompile
sudo systemctl restart puma
```

> `.gitignore` で `public/assets/` が除外されていることを確認済みの前提です。`git status` で意図せず含まれていないか都度確認してください。

---

## Webpacker

> 要確認: 今回のセッションでは `bin/webpack` のビルド実行やWebpacker固有の設定変更を直接行っていません。以下は一般的な手順です。

```bash
cd /home/ec2-user/be-my-style
yarn install --check-files
RAILS_ENV=production bundle exec rails webpacker:compile
```

`config/webpacker.yml` の `production` セクションで `compile: false` になっていることを確認し(ビルド済み成果物を使う運用の場合)、都度 `assets:precompile` と合わせて実行してください。

---

## S3

ActiveStorageの保存先として使用(`service_name=amazon`)。今回の調査で以下を確認済み:

- 認証情報は `credentials.yml.enc` の `aws.access_key_id` / `aws.secret_access_key` から取得(**ENV変数ではない**)
- バケット自体・IAMポリシーは移行不要(EC2から到達できればよい)
- 動作確認は以下の通り(値は表示せず、存在確認のみ):

```ruby
diagnosis = SingingDiagnosis.find_by(id: <任意のID>)
blob = diagnosis.audio_file.blob
puts "service_name=#{blob.service_name}"
puts "S3 object exists=#{ActiveStorage::Blob.service.exist?(blob.key)}"
```

---

## SSL

> 要確認: 今回のセッションでは直接作業していません。以下は一般的な流れです。

1. DNSのAレコードを新EC2のElastic IPへ切り替え(TTLを考慮し、事前に短くしておく)
2. Nginx(80番)が新EC2で正しく応答することを確認
3. Certbotで証明書を発行(下記参照)
4. Nginxの443番設定を反映し、`https://` でアクセスできることを確認
5. 旧証明書の失効・旧EC2の停止は、新EC2での動作確認が完全に終わってから行う

---

## Certbot

> 要確認: 今回のセッションでは直接作業していません。一般的な手順を記載します。実施時に実際に使ったコマンド・証明書の設定方法(Nginxプラグイン利用有無等)に更新してください。

```bash
sudo dnf install -y certbot python3-certbot-nginx
sudo certbot --nginx -d <ドメイン>

# 自動更新の確認
sudo certbot renew --dry-run

# 自動更新のcron/systemdタイマー確認
sudo systemctl list-timers | grep certbot
```

---

## Stripe

> 要確認: 今回のセッションではStripe関連の調査・変更は行っていません。CLAUDE.md記載の通り、Stripe関連コード(`app/services/stripe/`)・Webhook・Plan/Price IDの変更は**必ずユーザーに確認**してから実施してください。

移行時に確認すべき点(次回実施時に埋めてください):
- Stripe APIキー(本番用)が `credentials.yml.enc` または systemd Environment のどちらで管理されているか
- テスト環境と本番環境でキーが異なる点を再確認
- Price ID / Plan IDがハードコードされていないか

---

## Stripe Webhook

> 要確認: 今回のセッションでは未確認です。

移行時のポイント(一般論):
- WebhookのエンドポイントURLは基本的にドメイン単位のため、DNS切り替えが完了すれば自動的に新EC2で受信されるはずですが、**Stripeダッシュボード側のWebhook設定URLが旧EC2のIPを直接指定していないか**必ず確認してください。
- Webhook署名検証用のシークレット(`whsec_...`)が新環境に正しく設定されているか確認。
- 移行後、Stripeダッシュボードの「Webhookを送信」でテストイベントを送り、200が返ることを確認する。

---

## singing_analyzer

歌声・演奏診断のFastAPIサービスです。**今回の移行作業で最も重大な問題が見つかった箇所**(詳細は[今回ハマったポイント](#今回ハマったポイント))。

### セットアップ手順(今回実施し、動作確認済み)

```bash
cd /home/ec2-user/be-my-style/singing_analyzer

# 1. pipの導入(AL2023はpython3標準にpipが含まれないため明示インストールが必要)
sudo dnf install -y python3-pip

# 2. venv作成
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip

# 3. 依存インストール
pip install -r requirements.txt
```

`requirements.txt` の内容(参考):
```
fastapi==0.115.12
uvicorn[standard]==0.34.2
python-multipart==0.0.20
httpx==0.28.1
numpy==2.0.2
soundfile==0.13.1
pytest==8.3.5
```

### エンドポイント

- `GET /health` → `{"status":"ok"}`
- `POST /diagnoses`(multipart/form-data: `audio_file`, `diagnosis_id`, `performance_type`, `song_title`, `memo`, 任意で `reference_key`, `reference_bpm`)

### Railsとの接続設定

`puma.service.d/singing-analyzer.conf`:
```ini
[Service]
Environment=SINGING_ANALYZER_DIAGNOSES_URL=http://127.0.0.1:8000/diagnoses
```

Rails側の設定優先順位(`app/services/singing_diagnoses/analyzer_client.rb`):
1. `ENV["SINGING_ANALYZER_DIAGNOSES_URL"]`
2. `Rails.application.credentials.dig(:singing_analyzer, :diagnoses_url)`
3. (development環境限定のフォールバック `http://127.0.0.1:8000/diagnoses`。**本番では使われない**)

systemdサービス化については[systemd](#systemd)セクション参照。

---

## ffmpeg

`m4a`/`mp3` の音声デコードに必須(`singing_analyzer` の依存)。**Amazon Linux 2023の標準dnfリポジトリには含まれていません**(ライセンス上の理由)。

### 導入手順(今回実施・動作確認済み)

```bash
cd /tmp
curl -fL -o ffmpeg-btbn.tar.xz \
  https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz
tar xf ffmpeg-btbn.tar.xz

sudo cp ffmpeg-master-latest-linux64-gpl/bin/ffmpeg /usr/local/bin/
sudo cp ffmpeg-master-latest-linux64-gpl/bin/ffprobe /usr/local/bin/
sudo chmod +x /usr/local/bin/ffmpeg /usr/local/bin/ffprobe

# 後片付け
rm -rf /tmp/ffmpeg-btbn.tar.xz /tmp/ffmpeg-master-latest-linux64-gpl

# 動作確認
/usr/local/bin/ffmpeg -version
```

> **注意**: READMEに記載の `johnvansickle.com` の静的ビルドは、本番VPCのネットワーク制限により**接続タイムアウトします**(PyPI・GitHubへの到達は問題なし)。理由は[今回ハマったポイント](#今回ハマったポイント)を参照。**GitHub(BtbN/FFmpeg-Builds)を使ってください。**

`singing-analyzer.service` の `PATH` に `/usr/local/bin` を含めることを忘れないこと(`app/main.py` からの `ffmpeg` 呼び出しがPATH解決に依存する場合のため)。

---

## uvicorn

`singing_analyzer` のASGIサーバー。venv内にインストール済み(`requirements.txt` に含まれる)。

### 手動起動での動作確認(systemd化する前に必ず実施)

```bash
cd /home/ec2-user/be-my-style/singing_analyzer
source .venv/bin/activate
uvicorn app.main:app --host 127.0.0.1 --port 8000
```

別ターミナルから:
```bash
curl http://127.0.0.1:8000/health
# → {"status":"ok"}

curl -X POST http://127.0.0.1:8000/diagnoses
# → 422 (バリデーションエラーのJSON。"Connection refused"にならなければ疎通OK)
```

問題なければ `Ctrl+C` で停止し、[systemd](#systemd)の `singing-analyzer.service` に切り替えます(本番運用は必ずsystemd管理下で行う。手動起動プロセスを放置しない)。

---

## OpenAI

歌唱診断結果に対するAIコメント生成に使用(`app/services/singing_diagnoses/open_ai_responses_client.rb` 相当)。

### 設定方法

`puma.service.d/openai.conf`:
```ini
[Service]
Environment="OPENAI_API_KEY=sk-xxxx"
```

**クォートの対応に注意**(片方だけだと `systemd-analyze verify` で `Invalid syntax, ignoring` となり、キーが読み込まれません。詳細は[今回ハマったポイント](#今回ハマったポイント))。

### 反映確認(値を出力しない方法)

```bash
sudo systemctl daemon-reload
sudo systemctl restart puma

# 存在確認のみ(-o で該当キー名だけを抽出、値は出力しない)
sudo systemctl show puma --property=Environment --no-pager | grep -o "OPENAI_API_KEY"

# より確実な確認: 実プロセスの環境変数を直接確認(名前と文字数のみ)
puma_pid=$(sudo systemctl show puma --property=MainPID --value)
sudo cat /proc/$puma_pid/environ | tr '\0' '\n' | \
  awk -F'=' '{ printf "%s: present=true length=%d\n", $1, length($0)-length($1)-1 }' | \
  grep OPENAI_API_KEY
```

---

## LINE

LINE連携(チャネルシークレット・アクセストークン)。

`puma.service.d/override.conf`:
```ini
[Service]
Environment="LINE_CHANNEL_SECRET=xxxx"
Environment="LINE_CHANNEL_ACCESS_TOKEN=xxxx"
```

反映確認はOpenAIと同様の方法で、`LINE_CHANNEL_SECRET` / `LINE_CHANNEL_ACCESS_TOKEN` の**キー名の存在のみ**を確認してください。

> LINEチャネルのWebhook URL設定もドメイン単位のため、DNS切り替え後に到達性を再確認してください(Stripe Webhookと同様の注意点)。

---

## ActiveStorage

保存先はS3(`config/storage.yml` の `amazon` service)。[S3](#s3)セクション参照。

移行時の確認ポイント:
- `config/environments/production.rb` で `config.active_storage.service = :amazon` になっていること
- S3バケットのリージョン・バケット名が変わっていないこと(通常、EC2移行だけならS3側の変更は不要)

---

## Gmail

> 要確認: 今回のセッションでは未確認です。ActionMailerのSMTP設定(Gmail経由でのメール送信)を利用している場合、以下を移行時に確認してください。

- `config/environments/production.rb` の `config.action_mailer.smtp_settings`
- Gmailアプリパスワード or OAuth2認証情報の格納場所(credentials.yml.enc想定、要確認)
- 送信テスト: `ActionMailer::Base.mail(...).deliver_now` 相当をrails consoleで実行し、実際に届くか確認

---

## GoogleMap

> 要確認: 今回のセッションでは未確認です。Google Maps APIキーを使用している機能がある場合、以下を確認してください。

- APIキーの格納場所(credentials.yml.enc / ENV / フロントエンドの環境変数、いずれか要確認)
- Google Cloud Console側でAPIキーのHTTPリファラー制限に**新ドメイン/新IPが登録されているか**(登録されていないとブラウザからのリクエストが403になる)

---

## AIコメント

歌唱診断完了後、OpenAI経由で生成されるコメント機能。

### フロー

1. `SingingDiagnoses::SubmitToAnalyzerJob` が `singing_analyzer` にPOSTし、結果を `SingingDiagnoses::ResultPersister` が保存
2. 診断対象customerが `has_feature?(:singing_diagnosis_ai_comment)`(=`premium`プランまたは管理者)の場合、`ai_comment_status: ai_comment_queued` にして `SingingDiagnoses::GenerateAiCommentJob` をenqueue
3. `GenerateAiCommentJob` がOpenAI APIを呼び出し、成功すれば `ai_comment_status: ai_comment_completed`

### 本番でのJob実行環境について(重要)

`ActiveJob::Base.queue_adapter` は本番で `AsyncAdapter` です。つまり**Jobは Puma ワーカープロセス内で実行されます**。そのため:
- `OPENAI_API_KEY` 等の環境変数変更は、**Puma再起動後でないと反映されません**。
- `rails runner`(SSH直接実行)で動作確認する場合、SSHセッションのENVにはsystemd経由の環境変数(`OPENAI_API_KEY`, `SINGING_ANALYZER_DIAGNOSES_URL`等)が含まれないため、**「本番のPumaでは動くのにrails runnerでは動かない」という現象が起きます**。動作確認時は明示的に環境変数を渡してください(詳細は[今回ハマったポイント](#今回ハマったポイント))。

### 動作確認手順(テスト用アカウントを使う場合の推奨フロー)

1. テスト用customerを作成(`is_owner: :admin` にすると `has_feature?` が常にtrueになり、プラン契約なしでAI機能をテストできる)
2. 短い無音の `.m4a` をffmpegで生成: `ffmpeg -f lavfi -i anullsrc=r=44100:cl=mono -t 1 -c:a aac test.m4a`
3. `SingingDiagnosis` を作成し `audio_file` を添付、`SubmitToAnalyzerJob` を実行 → `status: completed` を確認
4. `GenerateAiCommentJob` を実行 → `ai_comment_status: ai_comment_completed` かつ `ai_comment` が生成されていることを確認
5. **必ずテスト用データ(diagnosis・関連する `SingingAchievementBadge`・customer)を削除する**(下記トラブルシューティング参照。バッジの外部キー制約で削除順序に注意)

---

## 動作確認チェックリスト

移行作業完了後、以下を順に確認してください。

### インフラ層
- [ ] `cat /etc/os-release` で `VERSION="2023"` を確認
- [ ] `sudo systemctl status puma` が `active (running)`
- [ ] `sudo systemctl status singing-analyzer` が `active (running)`
- [ ] `sudo systemctl status nginx` が `active (running)`
- [ ] `sudo systemctl is-enabled puma singing-analyzer nginx` が全て `enabled`(OS再起動後の自動起動)
- [ ] `sudo journalctl -u puma -n 50 --no-pager` にERROR/FATALがない
- [ ] `sudo journalctl -u singing-analyzer -n 50 --no-pager` にERROR/FATALがない
- [ ] `sudo systemd-analyze verify puma.service` / `singing-analyzer.service` で `Invalid syntax` が出ない

### 環境変数(値は表示せず、名前と文字数のみ確認)
- [ ] `OPENAI_API_KEY` が Puma実プロセスの環境に存在する
- [ ] `LINE_CHANNEL_SECRET` / `LINE_CHANNEL_ACCESS_TOKEN` が存在する
- [ ] `SINGING_ANALYZER_DIAGNOSES_URL` が存在する(`http://127.0.0.1:8000/diagnoses`)
- [ ] `DB_HOST` / `DB_DATABASE` / `DB_USERNAME` / `DB_PASSWORD` が存在する
- [ ] `RAILS_ENV` が `production`

### アプリケーション層
- [ ] `DISABLE_SPRING=1 bundle exec rails runner 'puts "boot ok"'` が正常終了
- [ ] `curl http://127.0.0.1:8000/health` → `{"status":"ok"}`
- [ ] `curl -X POST http://127.0.0.1:8000/diagnoses` → 422(接続拒否ではない)
- [ ] トップページ・ログインがブラウザから正常に表示される(HTTPS)
- [ ] 歌唱診断を実際に1件実行し、`status: completed` まで進む
- [ ] AIコメントが生成される(premiumプラン or 管理者アカウントで確認)
- [ ] ActiveStorageの画像/音声アップロードがS3に保存される
- [ ] Stripeの決済フロー(テストモード推奨)が正常に動く
- [ ] Stripe Webhookが200で受信される
- [ ] LINE Webhookが200で受信される
- [ ] メール送信(Gmail経由)が届く
- [ ] Google Mapを使う画面が正常表示される(APIキーのリファラー制限を確認)
- [ ] cron/スケジューラー系(`docs/handover/recap_movie_*`, `learning_*_reminders.md` 等)が新環境で動作する

---

## トラブルシューティング

### 「診断処理に一時的に失敗しました。時間をおいて再度お試しください。」と表示される

→ `singing_analyzer` への接続失敗。以下を確認:
```bash
sudo journalctl -u puma -n 200 --no-pager | grep -i "SubmitToAnalyzerJob\|ECONNREFUSED"
sudo systemctl status singing-analyzer
curl http://127.0.0.1:8000/health
```
`ECONNREFUSED` が出ていれば `singing-analyzer.service` が起動していません。[singing_analyzer](#singing_analyzer)セクションのセットアップ手順を再実施してください。

### AIコメントが生成されない

→ [debug_ai_comment スキル](../../.claude/rules/debug_rules.md) の手順、および本ドキュメントの[AIコメント](#aiコメント)セクションを参照。特に:
1. `OPENAI_API_KEY` が `present=true length=0`(空文字)になっていないか
2. Puma再起動後か(環境変数変更はPuma再起動まで反映されない)
3. `systemd-analyze verify` で該当行が `Invalid syntax, ignoring` になっていないか

### OpenAI APIが500エラーを返す

OpenAI側の一時的なサーバーエラー(`server_error`)の場合があります。設定不備(`ConfigurationError`)ではなく `RequestError` として記録されていれば、キー自体は正しく認識されています。数回リトライしても改善しない場合はOpenAI Status Pageを確認してください。

### `ffmpeg: command not found`

AL2023の標準リポジトリにffmpegはありません。[ffmpeg](#ffmpeg)セクションの手順でGitHub(BtbN)から導入してください。`johnvansickle.com` は本番VPCから到達できない場合があります。

### テスト用の`SingingDiagnosis`が削除できない(外部キー制約エラー)

```
Mysql2::Error: Cannot delete or update a parent row: a foreign key constraint fails
(`singing_achievement_badges`, CONSTRAINT ... FOREIGN KEY (`singing_diagnosis_id`) ...)
```
→ 診断完了時に実績バッジが自動付与されるため。削除順序は「バッジ → 診断 → customer」:
```ruby
SingingAchievementBadge.where(singing_diagnosis_id: diagnosis.id).destroy_all
diagnosis.audio_file.purge if diagnosis.audio_file.attached?
diagnosis.destroy!
customer.destroy!
```

### `rails runner` で動作確認すると環境変数が反映されない

`rails runner`(SSH直接実行)はSSHセッションのENVを使い、Pumaはsystemd経由のENVを使います。両者は別物です。動作確認時は明示的にexportするか、稼働中のPumaプロセスから値を継承してください:
```bash
puma_pid=$(sudo systemctl show puma --property=MainPID --value)
OPENAI_LINE=$(sudo cat /proc/$puma_pid/environ | tr '\0' '\n' | grep '^OPENAI_API_KEY=')
export "$OPENAI_LINE"
SINGING_ANALYZER_DIAGNOSES_URL="http://127.0.0.1:8000/diagnoses" \
  RAILS_ENV=production bundle exec rails runner ...
```

---

## 今回ハマったポイント

今回のAL2→AL2023移行で実際に発生した問題と原因のまとめです。次回移行時の事前チェックリストとして活用してください。

1. **`singing_analyzer`(FastAPI)一式が新EC2に未セットアップだった**
   Python venv・依存パッケージ・ffmpeg・uvicorn・systemdユニットのすべてが欠落しており、`http://127.0.0.1:8000` への接続が `ECONNREFUSED` になっていた。これが歌唱診断失敗の直接原因。**Railsアプリ本体だけでなく、singing_analyzerのような補助サービスも移行チェックリストに明記しておくべき。**

2. **AL2023には `ffmpeg` が標準リポジトリに存在しない**
   ライセンス上の理由でAmazon純正リポジトリに含まれない。`johnvansickle.com` の静的ビルドを使う手順がREADMEにあったが、**本番VPCからこのホストへの接続がタイムアウト**した(PyPI・GitHubへの到達は問題なし)。ネットワークがフルオープンでないVPC構成の場合、ダウンロード元ごとに到達性が異なることがある。GitHub(BtbN/FFmpeg-Builds)への切り替えで解決。

3. **AL2023には `python3-pip` が標準で入っていない**
   `python3 -m pip` が `No module named pip` になる。`sudo dnf install -y python3-pip` が必要(AL2ではpreinstall済みだった可能性がある)。

4. **systemd `Environment=` のクォート未閉じによるサイレント障害**
   `OPENAI_API_KEY` と `LINE_CHANNEL_ACCESS_TOKEN` の行が、閉じクォート `"` を欠いた状態で書かれていた(値の一部を切り詰めて貼り付けた際のミスと推測)。**systemdはこれをエラーにせず `Invalid syntax, ignoring` として黙って無視する**ため、`daemon-reload` や `restart` を何度実行しても該当キーだけ反映されない状態が続いた。`sudo systemd-analyze verify <unit>` で発見できる。今後、環境変数ファイルを編集した際は必ずこのコマンドで検証すること。

5. **`puma.service` 本体にdrop-in相当の内容が誤って埋め込まれていた**
   本来 `/etc/systemd/system/puma.service.d/*.conf` に分離されるべき環境変数が、ベースの `puma.service` ファイル自体に(`systemctl cat` の出力をそのまま貼り付けたような形跡で)重複して書き込まれていた。実際に存在した drop-in ファイルは `env.conf` のみで、残り(`openai.conf` 等の内容)はコメント付きでベースファイルに紛れ込んでいた。**`sudo cat` で単一ファイルのはずが複数ファイル分の内容が出てきたら、この種の事故を疑うこと。**

6. **`rails runner` とPumaで環境変数の見え方が異なる**
   `rails runner`(SSH直接実行)はSSHセッションのENVを参照し、systemd経由でPumaにのみ設定された環境変数(`SINGING_ANALYZER_DIAGNOSES_URL`, `OPENAI_API_KEY`等)を引き継がない。この違いに気づかず動作確認すると「設定されていないはずなのに本番では動いている/その逆」という混乱が起きる。動作確認は必ずPumaプロセスと同じ環境変数条件で行うこと。

7. **AsyncAdapterのため環境変数変更はPuma再起動が必須**
   本番の `ActiveJob::Base.queue_adapter` は `AsyncAdapter` であり、JobはPumaワーカープロセス内で動く。そのため環境変数を書き換えても `daemon-reload` だけでは反映されず、**必ず `systemctl restart puma` が必要**。

8. **実績バッジ(`SingingAchievementBadge`)による外部キー制約**
   テスト用に作成した診断を削除する際、診断完了時に自動付与されたバッジが外部キー制約で残っており削除に失敗した。削除順序(バッジ→診断→customer)を守る必要がある。

9. **OpenAI APIの一過性500エラー**
   キー設定を正しく直した直後の1回目の呼び出しで `server_error`(500)が発生。設定不備ではなくOpenAI側の一時的な問題で、リトライで解消した。500エラー=設定ミスと即断しないこと。

---

## 移行後チェックリスト

本番切り替え直前・直後に実施する最終確認です。

### 切り替え前
- [ ] 新EC2で[動作確認チェックリスト](#動作確認チェックリスト)を全項目クリア
- [ ] `RAILS_ENV=production bundle exec rails assets:precompile` を実行済み
- [ ] `bundle exec rspec` が新EC2上(または CI)で通ることを確認
- [ ] `git diff --check` でホワイトスペース/マーカー混入がないことを確認
- [ ] DBマイグレーション状態が旧EC2と一致(`RAILS_ENV=production bundle exec rails db:migrate:status`)
- [ ] SSL証明書が新EC2で有効(Certbot)
- [ ] DNSのTTLを事前に短縮しておく(切り戻しを容易にするため)

### 切り替え直後
- [ ] DNS Aレコードを新EC2のElastic IPへ切り替え
- [ ] `https://<本番ドメイン>` で新EC2に到達していることを確認(`dig` / ブラウザ)
- [ ] ログイン・歌唱診断・決済・LINE連携・メール送信を実際に1回ずつ実施
- [ ] `sudo journalctl -u puma -f` / `sudo journalctl -u singing-analyzer -f` をしばらく監視し、ERRORが出ないことを確認
- [ ] Nginxアクセスログ・エラーログを確認(`/var/log/nginx/`)
- [ ] cron/スケジューラー系ジョブ(recap movie, learning reminders等)が新環境で発火することを確認

### 切り替え後、安定稼働を確認してから
- [ ] 旧EC2を停止(即削除はしない。ロールバックの余地を残す)
- [ ] 旧EC2で使っていたElastic IPの解放(コスト削減、旧EC2の完全撤去が確定してから)
- [ ] 今回のトラブルシューティング内容を本Wikiおよび `docs/handover/` に反映し、次回移行のために更新する
- [ ] 露出・破損していた `OPENAI_API_KEY` / `LINE_CHANNEL_ACCESS_TOKEN` 等、機密情報のローテーションが完了していることを再確認
