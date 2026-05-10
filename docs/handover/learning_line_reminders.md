# Learning LINEリマインド運用メモ

## 手動実行

まずは本番で手動実行して、通知ログとLINE到達を確認する。

```bash
RAILS_ENV=production DISABLE_SPRING=1 bundle exec rails learning:send_reminders DRY_RUN=1
RAILS_ENV=production DISABLE_SPRING=1 bundle exec rails learning:send_reminders
```

特定顧問だけ確認する場合:

```bash
RAILS_ENV=production DISABLE_SPRING=1 bundle exec rails learning:send_reminders CUSTOMER_ID=123
```

## ENV

- `LINE_CHANNEL_ACCESS_TOKEN` が空の場合、LINE送信は行わず通知ログは `skipped` になる。
- 値そのものはログに出さない。確認は `line_token_configured=true/false` のみ。
- `LINE_CHANNEL_SECRET` はWebhook署名検証用。送信taskでは使用しない。

## 連携時の自動返信

Rails の `Learning::LineWebhookProcessor` は連携tokenを受け取って `line_user_id` を保存するだけで、LINE Reply API は呼び出していない。
連携メッセージ送信後に「個別のお問い合わせを受け付けておりません」などの自動返信が届く場合は、LINE Official Account Manager 側の「あいさつメッセージ」「応答メッセージ」「AI応答メッセージ」を確認する。
Learning連携文脈では、以下のような歓迎文言に変更する。

```text
LINE連携ありがとうございます！
これでBeMyStyle Learningからリマインドを受け取れるようになりました。
次回の配信をお楽しみに！
```

## 二重送信防止

`NotificationDispatcher` が `NotificationLog` を使い、同一顧問・同一生徒・同一種別・同一日のログを再利用する。
同日のログがすでに `sent / skipped / failed` の場合は再送しない。

## 定期実行案

初期運用は手動実行から開始する。
到達確認後、EC2上のcronまたはsystemd timerで1日1回実行する。

cron例:

```cron
0 18 * * * cd /path/to/be-my-style && RAILS_ENV=production DISABLE_SPRING=1 bundle exec rails learning:send_reminders >> log/learning_line_reminders.log 2>&1
```

systemd timerはログ集約や失敗検知をしやすい。EC2運用に寄せるならsystemd timerを推奨する。
GitHub Actionsから本番へ直接通知送信する運用は、秘密情報とネットワーク経路が増えるため現時点では非推奨。
