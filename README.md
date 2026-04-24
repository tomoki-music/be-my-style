# <img src="#" alt="BeMyStyle Logo" width="50" height="50"> BeMyStyle
## <img src="#" alt="BeMyStyle Logo" width="40" height="40"> サイト概要
### <img src="#" alt="BeMyStyle Logo" width="30" height="30"> サイトテーマ
「BeMyStyle」は、趣味で音楽（セッションバンド演奏）を楽しみたい人に向けた、音楽人の為のコミュニティサイトです。

### <img src="#" alt="BeMyStyle Logo" width="30" height="30"> このアプリに関する運営方針
このサイトは、「趣味」で音楽演奏を楽しみたい人の為に運営されます。
- 初心者歓迎: 音楽経験の浅い初心者の方にも安心してご利用頂けるよう、セッションを運営しております。
- 意見の尊重: コミュニティには色んな方が集まります。意見の違いを否定せず楽しみ、尊重できることを重要視しています。
- コミュニティの意義: コミュニティ内でバンドメンバーを見つける事は構いませんが、基本的にはコミュニティ内での活動はセッションとなります。
色んな人と色んな演奏体験を楽しんで頂けたらと思います。
​
### <img src="#" alt="BeMyStyle Logo" width="30" height="30"> テーマを選んだ理由
「好き」な事で繋がるコミュニティから生まれるご縁を大切にしたい。
そんな気持ちでコチラのテーマを採用し、アプリ開発をしております。
- 大人になってから趣味の時間を持っていない。仕事ばかり。
- 趣味はあるけど、一人でやっていてもつまらない。
- せっかくなら繋がりから何か面白い企画をやってみたい。
そんな気持ちを実現するサポートの為に「BeMyStyle」作りました。
また「音楽」は誰にとっても身近であり、気軽に始められる趣味でもあります。
ぜひ、普段の生活の「１色」プラスする感覚でご参加頂けたらと思います。
​
### <img src="#" alt="BeMyStyle Logo" width="30" height="30"> ターゲットユーザー
- バンド演奏初心者
- 何か趣味を持ちたい人
- 地域で貢献活動に興味ある方


​
### <img src="#" alt="BeMyStyle Logo" width="30" height="30"> 主な利用シーン
- 休日のイベント参加
- 興味のあるコミュニティ参加
- 趣味の合うメンバーと繋がる
- みんなの活動報告


<!-- ## <img src="#" alt="BeMyStyle Logo" width="30" height="30"> 設計書 -->

## <img src="#" alt="BeMyStyle Logo" width="30" height="30"> 開発環境
- OS：Linux(CentOS)
- 言語：HTML,CSS,JavaScript,Ruby(3.1.2),SQL
- フレームワーク：Ruby on Rails
- JSライブラリ：jQuery
- クラウドストレージ：Amazon S3 EC2

### Required
* ImageMagick(v7.1.1-5)
sudo yum -y install libpng-devel libjpeg-devel libtiff-devel gcc-c++ git
git clone -b 7.1.1-5 --depth 1 https://github.com/ImageMagick/ImageMagick.git ImageMagick-7.1.1-5
cd ImageMagick-7.1.1-5
./configure
make
sudo make install
* ChromeDriver
* MySQL
* Node.js
curl --silent --location https://rpm.nodesource.com/setup_16.x | sudo bash -
sudo yum install -y nodejs

## 歌唱・演奏診断APIのローカル接続

歌唱・演奏診断はRailsからFastAPIの `/diagnoses` に音声ファイルを送信します。
ローカルでは先にFastAPIを起動してください。スマホ録音で多い `m4a` や `mp3` を読むため、
FastAPI側では `ffmpeg` を使います。

```bash
brew install ffmpeg
cd singing_analyzer
python -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

別ターミナルでRailsを起動します。

```bash
export SINGING_ANALYZER_DIAGNOSES_URL=http://localhost:8000/diagnoses
bin/rails s
```

Rails development環境では、`SINGING_ANALYZER_DIAGNOSES_URL` とcredentialsが未設定の場合に
`http://localhost:8000/diagnoses` をデフォルトとして使います。FastAPIを別ポートで起動する場合は、
上記の環境変数を設定してからRailsを再起動してください。

疎通確認:

```bash
curl http://localhost:8000/health
```

`/singing/diagnoses/new` から診断を作成し、詳細画面で `completed` になれば接続成功です。

## 歌唱・演奏診断AIコメントのOpenAI接続

Premium向けのAIコメント生成はOpenAI Responses APIを使います。
ローカルでは以下の環境変数を設定してからRailsを再起動してください。

```bash
export OPENAI_API_KEY=sk-...
# 任意。未設定時は gpt-4.1-mini を使います。
export OPENAI_SINGING_AI_COMMENT_MODEL=gpt-4.1-mini
```

credentialsで設定する場合は以下のキーを使います。

```yaml
openai:
  api_key: sk-...
  singing_ai_comment_model: gpt-4.1-mini
  timeout_seconds: 20
```

APIキーが未設定、またはOpenAI APIでエラーになった場合でも、歌唱・演奏診断結果自体は `completed` のまま表示されます。
AIコメントだけ `ai_comment_failed` になり、失敗理由は `ai_comment_failure_reason` に保存されます。

## テストDBの準備

test環境はSQLiteを使います。development / production はMySQLのため、`db/schema.rb` にはMySQL由来の
collation名が含まれる場合があります。test環境では `config/initializers/sqlite_test_collations.rb` が
SQLiteに互換collationを登録し、schema load時の `utf8mb3_bin` エラーを回避します。

test DBを作り直す場合は、Rails環境を明示してから実行してください。

```bash
DISABLE_SPRING=1 RAILS_ENV=test bundle exec rails db:drop db:create db:schema:load
DISABLE_SPRING=1 bundle exec rspec
```

`db:test:prepare` を環境指定なしで実行すると development 側のMySQL接続を見に行くことがあるため、
ローカルでは上記の `RAILS_ENV=test` 付きコマンドを使ってください。
