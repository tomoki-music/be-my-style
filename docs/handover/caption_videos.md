# AIテロップ動画機能(MVP)

動画をアップロードすると、音声を自動文字起こしし、テロップを確認・編集した上で、
テロップを焼き込んだ完成動画をダウンロードできる機能。

対応範囲: MP4・MOV / 最大30分 / 最大500MB / 日本語 / 一人で話している動画。
複数話者識別・リアルタイム文字起こし・BGM追加・自動翻訳・課金処理等はMVPの対象外。

## 対応動画形式(MP4 / MOV)

対応拡張子: `.mp4` `.mov`(大文字小文字は区別しない)。
対応Content-Type: `video/mp4` `video/quicktime`。ブラウザ/OSがMOVに対して空文字や
`application/octet-stream`しか申告しない場合も、拡張子が正しければアップロードを許容する
(`CaptionVideo::GENERIC_SOURCE_CONTENT_TYPES`、正常なMOVを誤って拒否しないための緩和)。

**MOVを入力した場合も、完成動画は常にMP4(H.264/AAC/`+faststart`)で出力される。**
`CaptionVideos::VideoRenderer`は入力のコンテナ・コーデックによらず常に`libx264`/`aac`で
再エンコードするため、入力がMOV(HEVC/ProRes等)でも出力はMP4(H.264/AAC)になる。

### 拡張子・Content-Typeだけに頼らない検証

- `CaptionVideo`モデルのバリデーションは拡張子とContent-Typeの組み合わせによる一次チェック。
  ただしActive Storageの`direct_upload: true`はクライアントが申告したContent-Typeをそのまま
  受け取るため、悪意あるクライアントから見れば拡張子・Content-Typeは容易に詐称できる。
- 実体の検証は`CaptionVideos::ExtractAudioJob`が`CaptionVideos::VideoProbe`(ffprobe)で行う。
  動画ストリームの有無・コンテナ形式(`format_name`)を実ファイル解析で確認するため、
  拡張子だけMOVに変更した非動画ファイルはここで弾かれる(ユーザーへは内部コマンド・stderr・
  一時ファイルパス等の詳細を含まない汎用メッセージのみ表示し、詳細はサーバーログにのみ残す)。
- そのため「モデルバリデーションを通過した = 安全な動画」ではない。最終的な安全性はffprobeの
  実ファイル検証に依存する設計であり、これは元々MP4に対しても同じだった(既存の脅威モデルを
  MOVへそのまま拡張しただけで、新たな穴を開けてはいない)。

### iPhone/QuickTimeの回転メタデータ(縦動画)

iPhoneで撮影した縦向きMOVは、映像データ自体は横向きのまま(coded width/height)で、
回転角度をメタデータ(`side_data_list`のDisplay Matrix、または`tags.rotate`)として持つことが多い。

- `CaptionVideos::VideoProbe`はこの回転メタデータを読み取り、90/270度回転の場合は
  **表示上の幅・高さを入れ替えて**返す(`width`/`height`は常に表示上の値)。
  `CaptionVideo#width`/`#height`・アスペクト比・テロップ位置
  (`CaptionVideos::AssSubtitleGenerator`のPlayResX/PlayResY)は、すべてこの表示上の値を
  基準に計算される。
- テロップ焼き込み(`CaptionVideos::VideoRenderer`)では、ffmpegのmov/mp4デマルチプレクサの
  `autorotate`機能(ffmpeg 4.1以降でデフォルト有効)に回転適用を委譲している。`-vf`で指定した
  フィルタ(`ass=...`)の前段でffmpegが自動的に回転を適用するため、こちら側で明示的な
  `transpose`/`rotate`フィルタを追加する必要はない。**追加すると二重回転になるため
  絶対に追加しないこと**(`app/services/caption_videos/video_renderer.rb`のコメント参照)。
- この設計により、テロップの位置・サイズは常に最終的な(回転適用後の)映像サイズを基準に
  計算され、映像とテロップがずれることはない。

### HEVC(H.265)入力への対応について

MOVコンテナは映像コーデックとしてH.264だけでなくHEVC(H.265)やProResを含むことがある
(iPhoneは「高効率」設定でHEVCを使う)。

`CaptionVideos::AudioExtractor`(音声抽出)は`-vn`で映像を無視して音声のみ扱うため、
映像コーデックによらず動作する。一方`CaptionVideos::VideoRenderer`(テロップ焼き込み)は
入力を一度デコードしてから`libx264`で再エンコードするため、**入力デコードに対応した
映像コーデックのffmpegビルドが必要**。

**HEVCデコード対応はffmpegのビルド設定に依存するため、このドキュメントで「対応済み」と
断定することはできない。デプロイ前に必ず本番サーバー上で以下を確認すること。**

```bash
# ffmpegのバージョン・ビルド設定を確認
ffmpeg -version

# HEVC/H.264のデコーダーが有効か確認(それぞれ一覧に出れば対応)
ffmpeg -decoders | grep -E 'hevc|h264'

# 実際のHEVC MOVサンプルファイルで確認(事前に用意する。リポジトリへは追加しない)
ffprobe -v error -show_streams -show_format sample.mov
ffmpeg -y -i sample.mov -t 1 -f null -
```

- `ffmpeg -decoders`の出力に`hevc`のデコーダーが含まれていない場合、HEVC入力の動画生成
  (RenderJob)は失敗する(`VideoRenderer::RenderError`、ユーザーには「動画の生成に失敗しました。
  もう一度お試しください。」とだけ表示される。内部エラー詳細はログのみ)。
- 開発環境(Homebrewの`ffmpeg`)は通常フル機能ビルドでHEVCデコードに対応しているが、
  本番(Amazon Linux 2023)の`/usr/local/bin/ffmpeg`が同様とは限らないため、
  上記コマンドで個別に確認すること。**本ドキュメントは対応済みかどうかを推測で断定しない。**
- 音声抽出(ExtractAudioJob)はHEVC入力でも映像を読まないため問題なく動作する。したがって、
  HEVC非対応のffmpegビルドでは「アップロード・文字起こし・テロップ編集は成功するが、
  動画生成だけが失敗する」状態になりうる。これは既存の「日本語フォント未導入」ケース
  (本ドキュメント該当節)と同じ症状パターンのため、障害時はどちらも疑うこと。

### 音声が無いMOV/MP4の挙動

`CaptionVideos::VideoProbe`がffprobeの実ファイル解析で音声ストリームの有無を確認する。
音声ストリームが存在しない場合、`CaptionVideos::ExtractAudioJob`はffmpegによる音声抽出を
一切実行せずに(=ffmpegの内部エラーをユーザーへ見せることなく)以下のメッセージで
`failed`にする。

> この動画から音声を確認できませんでした。音声を含む動画をアップロードしてください。

### 開発・本番でのMOV E2E確認手順

```bash
# 1. サンプルMOVファイルを用意する(iPhoneで撮影したファイル、またはQuickTimeで書き出したファイル)
#    リポジトリへは追加しない(バイナリfixtureを避ける方針。自動テストはマジックバイトで代替)

# 2. ffprobeで事前確認(コーデック・回転メタデータ・音声有無)
ffprobe -v error -show_streams -show_format sample.mov \
  | grep -E 'codec_name|width|height|rotate|side_data_type|codec_type'

# 3. 開発環境でアップロードして一連の処理を確認する
#    (Railsサーバー起動中に /public/caption_videos/new からアップロード)
#    ログで CaptionVideos::ExtractAudioJob → TranscribeJob → (テロップ編集) → RenderJob の
#    各ステップが成功することを確認する。完成動画(rendered_video)がMP4であること、
#    縦動画の場合は向きが正しく、テロップ位置がずれていないことを目視確認する。

# 4. 本番デプロイ前チェック(HEVC対応の確認は上記「HEVC(H.265)入力への対応について」を参照)
ffmpeg -version
ffmpeg -decoders | grep -E 'hevc|h264'
sudo systemctl show puma --property=Environment | grep PATH   # ffmpeg/ffprobeのPATH確認(下記節参照)
```

## 処理フロー

```
アップロード(uploaded)
  → 音声抽出(extracting_audio)  ... CaptionVideos::ExtractAudioJob
  → 文字起こし(transcribing)    ... CaptionVideos::TranscribeJob
  → テロップ編集可能(ready_for_edit)
  → 動画生成(rendering)         ... CaptionVideos::RenderJob
  → 完成(completed) / 失敗(failed)
```

- 各ジョブは `CaptionVideo#status` を見て冪等に動作する(同じジョブが再実行されても
  二重に音声抽出/文字起こし/動画生成を行わない)。
- 本番はSidekiqを使わずActiveJobの `AsyncAdapter`(Puma ワーカー内実行)。専用ジョブキューが
  無いため、`CaptionVideos::RenderJob` は歌声診断Recap Movie機能と同じ方針で、
  動画エンコードのグローバル同時実行数を1件に制限している
  (`CaptionVideo.rendering.where.not(id: video.id).exists?` で判定)。

## 必要な環境変数

すべて未設定でも動作する(デフォルト値あり)。本番でOpenAI連携を使うには `OPENAI_API_KEY` が必須。

| 変数名 | 説明 | デフォルト |
|--------|------|-----------|
| `OPENAI_API_KEY` | OpenAI APIキー。歌声診断AIコメント機能と共用。空文字は未設定として扱われる(`.presence`)ので、systemd Unitで `Environment=OPENAI_API_KEY=` のように空にしないこと | なし(未設定時はConfigurationErrorでジョブがfailedになる) |
| `OPENAI_TRANSCRIPTION_MODEL` | 文字起こしに使うモデル | `whisper-1` |
| `OPENAI_TRANSCRIPTION_URL` | Transcriptions APIのエンドポイント | `https://api.openai.com/v1/audio/transcriptions` |
| `OPENAI_TRANSCRIPTION_TIMEOUT_SECONDS` | OpenAIリクエストのタイムアウト(秒) | `120` |
| `CAPTION_VIDEO_AUDIO_TIMEOUT_SEC` | ffmpegによる音声抽出のタイムアウト(秒) | `600` |
| `CAPTION_VIDEO_RENDER_TIMEOUT_SEC` | ffmpegによるテロップ焼き込みのタイムアウト(秒) | `3600` |
| `CAPTION_VIDEO_FONT_FAMILY` | テロップ焼き込みに使う日本語フォントのファミリー名(fontconfigで解決可能な名前) | `Noto Sans CJK JP` |
| `CAPTION_VIDEO_TMP_ROOT` | 各ジョブが使う一時ディレクトリのルート | `tmp/caption_videos` |

APIキーはコード・fixture・ログへ書かない。`Rails.application.credentials.dig(:openai, :api_key)` でも
設定可能(ENV優先)。歌声診断AIコメント機能(`docs/handover/ai_comment_debug.md`)と同じキーを共用する。

## 音声分割が不要な理由(OpenAI 25MB制限とMAX_DURATION_SECONDSの関係)

`CaptionVideos::AudioExtractor` は音声をモノラル・16kHz・64kbps(`AUDIO_BITRATE`)のMP3に
固定変換する。ビットレートが動画長によらず一定のため、抽出音声サイズは動画の長さにほぼ
比例する。`CaptionVideo::MAX_DURATION_SECONDS`(30分 = 1800秒)の場合:

```
1800秒 × 64,000bit/秒 ÷ 8 ≒ 14.4MB
```

OpenAI Whisper APIの25MB制限、および安全マージンを取った `AudioExtractor::MAX_AUDIO_BYTES`
(24MB)のいずれにも収まる(約60%)。そのため、動画の長さ上限が30分である限り、音声を
複数ファイルに分割してAPIへ送る処理は不要であり、実装していない。この前提は
`spec/services/caption_videos/audio_extractor_spec.rb` の不変条件テストで担保している。

**注意:** `MAX_DURATION_SECONDS` や `AUDIO_BITRATE` を将来さらに引き上げる場合は、
上記の計算を再確認し、24MBを超えるようであれば音声分割(タイムスタンプのオフセット補正を含む)
の実装を検討すること。

## FFmpeg / FFprobe

Rails側から直接 `ffmpeg` / `ffprobe` を `Open3` 経由で呼び出す(シェル経由ではなく引数配列で渡すため、
コマンドインジェクションの心配はない)。

- **開発環境**: Homebrew等で `brew install ffmpeg` すればそのまま動作する。
- **本番環境(Amazon Linux 2023)**: `docs/handover/al2023_migration_wiki.md` の手順で
  `/usr/local/bin/ffmpeg` / `/usr/local/bin/ffprobe` が既にPython製 `singing_analyzer` 用に
  導入済みだが、**それはRailsのPumaプロセスからは別PATHで動く**。Puma(systemd)の
  `Environment=PATH=...` に `/usr/local/bin` が含まれているか必ず確認すること。
  含まれていない場合、`AudioExtractor`/`VideoRenderer` は `Errno::ENOENT` (「ffmpeg is not
  installed or not on PATH」)で失敗する。

```bash
# 本番サーバー上で確認
sudo systemctl show puma --property=Environment | grep PATH
which ffmpeg ffprobe   # ec2-userのシェルで確認できても、Pumaから見えるとは限らない
```

## 日本語フォント(テロップ焼き込み用)

テロップはASS字幕として生成し、`ffmpeg -vf ass=...`(libass)で焼き込む。libassは
システムのfontconfigからフォントファミリー名で解決するため、**本番サーバーに日本語フォントが
インストールされていないと、テロップが文字化け(豆腐)して焼き込まれる**。

- ライセンス上の理由から、フォントファイル自体はこのリポジトリへ含めない
  (再配布条件が不明なフォントは追加しない方針)。
- 本番(Amazon Linux 2023)では以下のいずれかをdnfで導入し、`CAPTION_VIDEO_FONT_FAMILY` を
  実際に入ったパッケージのファミリー名に合わせること。

```bash
# 候補1: Google Noto Sans CJK JP (パッケージ名は配布リポジトリにより異なる場合がある)
sudo dnf install google-noto-sans-cjk-jp-fonts
# 候補2: IPAゴシック
sudo dnf install ipa-gothic-fonts
sudo fc-cache -f
fc-list | grep -i noto   # インストール後、ファミリー名を確認する
```

**本機能をデプロイする前に、上記のフォント導入とPATH確認を本番サーバーで実施する必要がある。**
未実施でもアップロード・文字起こし・テロップ編集は問題なく動くが、「動画生成」だけが失敗するか、
テロップが正しく表示されない状態になる。

## バックグラウンドワーカーの起動方法

既存のSinging Recap Movie機能等と同様、専用ワーカープロセスは無い。

- **開発環境**: `config.active_job.queue_adapter = :async` のため、`rails server` を
  起動していれば自動的にジョブが実行される。追加の起動作業は不要。
- **本番環境**: Puma(systemd)プロセス内で実行される(AsyncAdapter)。デプロイ後の
  `sudo systemctl restart puma` で反映される。詳細は `docs/handover/architecture.md` の
  ジョブキュー節を参照。

## 開発環境での確認方法

```bash
# 1. マイグレーション
DISABLE_SPRING=1 bundle exec rails db:migrate

# 2. ffmpeg/ffprobeが使えるか確認
which ffmpeg ffprobe

# 3. OPENAI_API_KEYを設定して(.envまたはcredentials)動画をアップロードし、
#    Railsサーバーのログで CaptionVideos::* ジョブの実行を確認する

# 4. テスト実行(外部API/ffmpegは全てモック化されており、実際には呼び出さない)
DISABLE_SPRING=1 bundle exec rspec spec/models/caption_video_spec.rb spec/models/video_caption_spec.rb \
  spec/services/caption_videos/ spec/jobs/caption_videos/ spec/requests/public/caption_videos_spec.rb
```

OpenAI APIキーを設定していない状態でアップロードすると、`ExtractAudioJob` 自体は成功し、
`TranscribeJob` が `ConfigurationError` で `failed` になる(実際に課金は発生しない)。

## 一時ファイルの扱い

`tmp/caption_videos/` (環境変数 `CAPTION_VIDEO_TMP_ROOT` で変更可)配下に
`Dir.mktmpdir` で作成し、各ジョブの処理完了後(ブロックを抜けるタイミング)に自動削除される。
処理途中で例外が発生した場合も `Dir.mktmpdir` のブロックが抜ける際に削除される。

## API料金について

- OpenAI Audio Transcriptions API (`whisper-1`) は音声の長さに応じて課金される。
  最大30分の動画を1本処理するごとに課金が発生する。
- `TranscribeJob` は `CaptionVideo#transcribed_at` で冪等性を担保しており、同じ動画に対して
  ジョブが再実行されても再度OpenAIを呼ばない(二重課金防止)。ユーザーが手動で「動画を生成する」を
  複数回押しても、OpenAI課金が発生するのは文字起こし(1回だけ)であり、動画生成(FFmpeg)自体は
  APIコストが発生しない。

## 障害時の確認箇所

1. `CaptionVideo#status` が `failed` の場合、`error_message` にユーザー向けの短いメッセージが
   入っている(内部エラー詳細やAPIレスポンス全文は意図的に含めていない)。
2. サーバーログで `[CaptionVideos::ExtractAudioJob]` / `[CaptionVideos::TranscribeJob]` /
   `[CaptionVideos::RenderJob]` のプレフィックスを検索すると、`error.class`/`error.message` の
   詳細(ただしAPIレスポンス全文・文字起こし全文はログに出さない設計)を確認できる。
3. OpenAI関連の失敗は `docs/handover/ai_comment_debug.md` のAPIキー確認手順
   (`.presence`/`.length`チェック、systemd Environment確認)がそのまま流用できる
   (同じ `OPENAI_API_KEY` を使用)。
4. 動画生成(`RenderJob`)だけが失敗する場合は、FFmpegのPATH・日本語フォント導入を疑う
   (本ドキュメントの該当節を参照)。
5. 元動画がMOV(特にHEVC)の場合のみ動画生成が失敗する場合は、本番ffmpegビルドの
   HEVCデコード対応を疑う(「HEVC(H.265)入力への対応について」節を参照)。
   音声抽出・文字起こし・テロップ編集は成功するのに動画生成だけ失敗する、という
   症状パターンになる。
