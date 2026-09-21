# AIテロップ動画機能(MVP)

動画をアップロードすると、音声を自動文字起こしし、テロップを確認・編集した上で、
テロップを焼き込んだ完成動画をダウンロードできる機能。

対応範囲: MP4 / 最大10分 / 最大500MB / 日本語 / 一人で話している動画。
複数話者識別・リアルタイム文字起こし・BGM追加・自動翻訳・課金処理等はMVPの対象外。

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
| `CAPTION_VIDEO_AUDIO_TIMEOUT_SEC` | ffmpegによる音声抽出のタイムアウト(秒) | `300` |
| `CAPTION_VIDEO_RENDER_TIMEOUT_SEC` | ffmpegによるテロップ焼き込みのタイムアウト(秒) | `1200` |
| `CAPTION_VIDEO_FONT_FAMILY` | テロップ焼き込みに使う日本語フォントのファミリー名(fontconfigで解決可能な名前) | `Noto Sans CJK JP` |
| `CAPTION_VIDEO_TMP_ROOT` | 各ジョブが使う一時ディレクトリのルート | `tmp/caption_videos` |

APIキーはコード・fixture・ログへ書かない。`Rails.application.credentials.dig(:openai, :api_key)` でも
設定可能(ENV優先)。歌声診断AIコメント機能(`docs/handover/ai_comment_debug.md`)と同じキーを共用する。

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
  最大10分の動画を1本処理するごとに課金が発生する。
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
