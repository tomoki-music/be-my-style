# Singing Analyzer API

Minimal FastAPI service for receiving singing diagnosis requests from Rails.

## Setup

`m4a` and `mp3` uploads are decoded through `ffmpeg`. Install it before running
the analyzer:

```bash
brew install ffmpeg
```

```bash
cd singing_analyzer
python -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
pip install -r requirements.txt
```

## Run

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Rails can point to:

```bash
SINGING_ANALYZER_DIAGNOSES_URL=http://localhost:8000/diagnoses
```

In Rails development, this URL is also used as the safe default when
`SINGING_ANALYZER_DIAGNOSES_URL` and credentials are both blank. Production and
test environments still require an explicit setting.

## Rails Local Connection Check

1. Start this FastAPI server:

   ```bash
   cd singing_analyzer
   source .venv/bin/activate
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

2. In another terminal, start Rails with the analyzer URL:

   ```bash
   export SINGING_ANALYZER_DIAGNOSES_URL=http://localhost:8000/diagnoses
   bin/rails s
   ```

   If Rails was already running, restart it after changing the environment
   variable. ActiveJob runs in the Rails process during development, so it reads
   the value that was present when Rails booted.

   The `export` is optional in development when FastAPI is running on
   `http://localhost:8000/diagnoses`, because Rails falls back to that URL.
   Keep the explicit `export` if you run FastAPI on a different host or port.

3. Sign in as a `singing` domain user and create a diagnosis from:

   ```text
   /singing/diagnoses/new
   ```

4. In development, ActiveJob uses the in-process `:async` adapter. After the request is created, refresh the diagnosis show page and confirm:

   - `status` becomes `completed`
   - scores are populated
   - `diagnosed_at` is present

5. If it becomes `failed`, check:

   - Rails log for `Singing diagnosis analyzer submission failed`
   - the diagnosis show page `失敗理由`
   - FastAPI server log

For a quick API-only check:

```bash
curl http://localhost:8000/health
```

## Endpoints

- `GET /health`
- `POST /diagnoses`
  - multipart/form-data: `audio_file`, `diagnosis_id`, `performance_type`, `song_title`, `memo`, optional `reference_key`, optional `reference_bpm`
  - `performance_type` は現在 `vocal` / `guitar` / `bass` / `drums` / `keyboard` を解析対応しています。
  - `guitar` の初期解析では、音量フレームの立ち上がり、切れ際、音量のばらつきから `attack_score`, `muting_score`, `stability_score` を軽量に算出します。
  - `bass` の初期解析では、低音楽器向けにリズム規則性、音価の切れ際、音量の安定から `groove_score`, `note_length_score`, `stability_score` を軽量に算出します。
  - `keyboard` の初期解析では、フレーム間のエネルギー変動、オンセットの粒の揃い、無音区間、スペクトルの安定性から `chord_stability_score`, `note_connection_score`, `touch_score`, `harmony_score` を軽量に算出します。
  - guitar / bass の解析テストでは、合成音によるAB比較で「立ち上がり」「ミュート」「グルーヴ」「音価」「安定感」の改善方向が逆転していないかを確認しています。
  - `tests/fixtures/guitar_regression/` と `tests/fixtures/bass_regression/` の短い `.wav` サンプルで、現実音源に近いファイル入力でも guitar / bass specific score が極端に破綻していないかを回帰チェックできます。サンプルを差し替える場合は各ディレクトリの README を確認してください。
  - keyboard の解析テストでは、合成音によるAB比較で「つながった音」「揃った打鍵」「安定した響き」「ノイズの少ない和音」が相対的に高く出ることを確認しています。
  - `tests/fixtures/keyboard_regression/` の短い `.wav` サンプルで、現実音源に近いファイル入力でも keyboard specific score が極端に破綻していないかを回帰チェックできます。サンプルを差し替える場合は同ディレクトリの README を確認してください。
  - `reference_key` / `reference_bpm` が送られた場合は、簡易推定したキー・テンポとの比較を `reference_comparison` に含めます。参照情報が無い場合は空のまま返します。
  - レスポンスは後方互換のため top-level の `overall_score`, `pitch_score`, `rhythm_score`, `expression_score` を維持しつつ、`schema_version`, `performance_type`, `common`, `specific` も返します。
