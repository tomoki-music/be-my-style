# band診断 デプロイ前後メモ

band診断の本番投入前後で、実行コマンドと確認観点をまとめたメモです。
画面項目そのもののチェックは `docs/band_diagnosis_release_checklist.md` を併用してください。

## 1. ローカル確認コマンド

### Rails

```bash
bundle exec rspec spec/helpers/singing/diagnoses_helper_spec.rb
bundle exec rspec spec/services/singing_diagnoses/ai_comment_generator_spec.rb
bundle exec rspec spec/requests/public/lp_spec.rb
```

補足:

- request spec は環境差分で 302 リダイレクト前提が混ざることがあります。
- その場合でも、helper / service / LP request spec が通るかは最低限確認しておくと安心です。

### FastAPI

```bash
cd singing_analyzer
python -m py_compile app/services/diagnosis_analyzer.py app/schemas.py
pytest tests/test_main.py
```

補足:

- `pytest` が未導入の場合は `python -m pytest tests/test_main.py` でも可です。
- それでも `No module named pytest` になる場合は、Python テスト依存が未導入です。
- その場合は少なくとも `py_compile` まで実行し、テストは環境整備後に再実行してください。
- `numpy` や `soundfile` などの依存が不足している環境では、FastAPI 側のテスト実行に失敗することがあります。環境に応じて調整してください。

## 2. 手動確認

- band を選んで診断作成できること
- diagnosis が `completed` になること
- 結果画面に「アンサンブル診断」が表示されること
- `quality_message` が必要なときだけ表示されること
- Premium ユーザーで週間アドバイスが表示されること
- 無料ユーザーでは Premium 誘導表示になること
- development 環境だけ `analysis_debug` / `Payload確認` が表示されること
- production 環境では開発者向け情報が表示されないこと

## 3. Rails console 確認例

```ruby
diagnosis = SingingDiagnosis.where(performance_type: "band").last
diagnosis.status
diagnosis.result_payload.keys
diagnosis.result_payload["specific"]
diagnosis.result_payload["quality_flags"]
diagnosis.result_payload["analysis_debug"]
```

あると見やすい追加確認:

```ruby
diagnosis.result_payload["performance_type"]
diagnosis.result_payload["quality_message"]
diagnosis.result_payload.dig("specific", "balance")
diagnosis.result_payload.dig("quality_flags", "low_confidence")
diagnosis.result_payload.dig("analysis_debug", "rms_mean")
```

## 4. 本番ログ確認

Rails / Web:

```bash
sudo journalctl -u puma -n 100 --no-pager
sudo tail -n 100 /var/log/nginx/error.log
```

補足:

- アプリ構成によっては `puma` の unit 名が異なる場合があります。
- systemd を使っていない環境では、ログ出力先に合わせて読み替えてください。

FastAPI:

```text
TODO: FastAPI を別 service / container / process manager で動かしている場合は、そのログ確認コマンドを環境に合わせて追記する
```

例:

- `sudo journalctl -u <fastapi-service-name> -n 100 --no-pager`
- `docker logs <fastapi-container-name> --tail 100`
- `pm2 logs <process-name> --lines 100`

## 5. リリース後の確認観点

- band診断で 500 エラーが出ていないか
- FastAPI 連携エラーが出ていないか
- `result_payload` が想定構造で保存されているか
- 無音 / 短尺 / 音割れ音源で注意文が出るか
- 既存の `vocal / guitar / bass / drums / keyboard` 診断が壊れていないか

## 6. 運用メモ

- band診断は `specific`, `quality_flags`, `quality_message`, `analysis_debug` を含むため、保存 payload の shape 崩れを早めに見るのが重要です。
- 開発環境では結果画面の `analysis_debug` と `Payload確認` を使うと、UI 上で不足キーをすぐ確認できます。
- production では開発者向け情報が出ないことを、初回リリース時に必ず確認してください。
- 低品質音源の注意表示は「診断停止」ではなく「参考値案内」のトーンなので、サポート問い合わせ時もその前提で案内するとスムーズです。
