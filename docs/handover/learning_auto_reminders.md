# Learning AutoReminder 本番初回運用手順書

## 機能概要

`Learning::AutoReminderService` は、顧問ごとの Learning 生徒に対して LINE 自動リマインド候補を作成し、rake task から DRY_RUN または手動送信できる。

本番ではいきなり定期実行化しない。まず `DRY_RUN=1` で候補と文面を確認し、顧問単位の ON/OFF、送信時間、プレビュー画面、ログを確認してから、特定顧問を手動送信する。

## 自動リマインド3種

- `auto_inactive_reminder`: 3日以上リアクションがない LINE 連携済み生徒への練習再開リマインド。
- `auto_assignment_due_reminder`: 期限が明日の未完了課題への前日リマインド。
- `auto_assignment_overdue_reminder`: 期限を過ぎた未完了課題への期限超過リマインド。

候補は期限超過、期限前日、未反応の順で優先される。同一生徒に複数候補がある場合でも、1回の実行では1日1通制御により複数送信されない。

## 顧問単位ON/OFF仕様

設定は `learning_notification_settings.auto_reminder_enabled` で顧問単位に管理する。

- `true`: 自動リマインド候補作成と送信対象になる。
- `false`: `Learning::AutoReminderService#runnable?` が false になり、DRY_RUNでも実送信でも候補は空になる。

設定画面から顧問本人が変更できる。初回運用前に対象顧問ごとに ON/OFF を確認する。

## send_hour仕様

設定は `learning_notification_settings.auto_reminder_send_hour` で管理する。

- `nil`: 時間指定なし。task 実行時刻に関係なく対象になる。
- `0..23`: task 実行時の `Time.current.hour` と一致した場合だけ対象になる。

たとえば `auto_reminder_send_hour=18` の顧問は、Rails の現在時刻が18時台の実行だけ対象になる。定期実行化する場合は、timer/cron の実行時刻と顧問設定の hour が合うようにする。

## プレビュー画面URL

ログイン済み顧問は以下で候補と文面を確認できる。

```text
/learning/auto_reminders
```

画面内では `Learning::AutoReminderService.new(current_customer, dry_run: true)` の結果を表示するため、LINE送信や `Learning::NotificationLog` 作成は行わない。

## ログ確認方法

Rails runner で secret 値を出さずに件数と直近ログだけ確認する。

```bash
RAILS_ENV=production DISABLE_SPRING=1 bundle exec rails runner 'puts Learning::NotificationLog.where(notification_type: Learning::NotificationLog::AUTO_REMINDER_TYPES).group(:notification_type, :status).count'
```

特定顧問だけ見る場合:

```bash
RAILS_ENV=production DISABLE_SPRING=1 bundle exec rails runner 'customer = Customer.find(123); puts customer.learning_notification_logs.where(notification_type: Learning::NotificationLog::AUTO_REMINDER_TYPES).order(created_at: :desc).limit(20).pluck(:id, :learning_student_id, :notification_type, :status, :error_message, :generated_at)'
```

task の標準出力には `line_token_configured=true/false` だけを出す。LINE token の値は絶対に表示しない。

## DRY_RUN手順

まず help を確認する。

```bash
RAILS_ENV=production DISABLE_SPRING=1 bundle exec rails learning:auto_reminders:help
```

全顧問候補を確認する。

```bash
RAILS_ENV=production DISABLE_SPRING=1 bundle exec rails learning:auto_reminders DRY_RUN=1
```

特定顧問だけ確認する。

```bash
RAILS_ENV=production DISABLE_SPRING=1 bundle exec rails learning:auto_reminders DRY_RUN=1 CUSTOMER_ID=123
```

確認する観点:

- `customers=` が想定対象数か。
- `target_customer=` が指定顧問か。
- `auto_reminder_enabled=true` か。
- `send_hour` が実行時刻と合っているか、または `none` か。
- 候補の `type`、`student_id`、`message` が自然か。
- DRY_RUN後に `Learning::NotificationLog` が増えていないか。

## 初回本番送信手順

初回は全顧問ではなく、対象顧問を1件に絞る。

1. 顧問の設定画面で `auto_reminder_enabled=true` と `send_hour` を確認する。
2. 顧問または運用者が `/learning/auto_reminders` で候補文面を確認する。
3. `DRY_RUN=1 CUSTOMER_ID=123` で CLI 上の候補を確認する。
4. 問題なければ confirm 付きで手動送信する。

```bash
RAILS_ENV=production DISABLE_SPRING=1 bundle exec rails learning:auto_reminders CUSTOMER_ID=123 CONFIRM_AUTO_REMINDER_SEND=1
```

5. task 出力の `sent/skipped/failed` を確認する。
6. `Learning::NotificationLog` の `status` と `error_message` を確認する。
7. 必要に応じて顧問へ LINE 到達状況を確認する。

全顧問への実送信は、特定顧問でログと到達確認が取れてから行う。

## 停止方法

即時停止したい場合は、顧問単位で `auto_reminder_enabled=false` にする。

定期実行化後は、systemd timer または cron の設定を無効化する。今回は本番サーバーに timer/cron を設定しない。

## トラブル時の確認ポイント

- `auto_reminder_enabled` が false ではないか。
- `auto_reminder_send_hour` と実行時刻の hour が一致しているか。
- 生徒が active か。
- 生徒に connected 状態の `Learning::LineConnection` があるか。
- 課題が open status か。
- 期限前日なら `due_on = Date.current.tomorrow` か。
- 期限超過なら `due_on < Date.current` か。
- 同一種別が24時間以内に送信済みで `duplicate_recently_sent` になっていないか。
- 同一生徒に24時間以内の自動リマインド送信済みがあり `auto_daily_limit` になっていないか。
- `LINE_CHANNEL_ACCESS_TOKEN` が空でないか。値は出さず、length または configured のみ確認する。

## LINE未連携が多い場合の対応

AutoReminder は LINE 連携済み生徒だけを対象にする。未連携が多い場合、候補数が少ない、または0件になる。

対応方針:

- 顧問へ LINE 連携導線を案内する。
- 生徒一覧で LINE 連携状態を確認する。
- 初回運用の成果指標は送信数だけでなく、連携率も別で見る。
- 未連携生徒へ勝手に別チャネル送信しない。

## duplicate_recently_sent の仕様

`Learning::NotificationLog.recently_sent_duplicate?` が、同一顧問・同一生徒・同一通知種別・LINE・`sent` のログを24時間以内で検索する。

該当する場合:

- 実送信では `status=skipped`、`error_message=duplicate_recently_sent` のログを作る。
- DRY_RUNではログを作らず、結果だけ `skipped` として表示する。

## 1日1通制御の仕様

`Learning::NotificationLog.auto_reminder_sent_today?` が、同一顧問・同一生徒・自動リマインド3種・LINE・`sent` のログを24時間以内で検索する。

該当する場合は `auto_daily_limit` で skipped になる。また、同じ task 実行内でも `handled_student_ids` により、同一生徒に複数候補があっても1件だけ処理する。

## 本番で絶対に確認するチェックリスト

- `main` へ直接 push していない。
- secrets、credentials、`.env` を参照・編集していない。
- Stripe 関連に触れていない。
- `public/assets/` をコミットしていない。
- 本番サーバーへ timer/cron を設定していない。
- `learning:auto_reminders:help` を確認した。
- 対象顧問の `auto_reminder_enabled` を確認した。
- 対象顧問の `send_hour` を確認した。
- `/learning/auto_reminders` で候補と文面を確認した。
- `DRY_RUN=1 CUSTOMER_ID=...` の結果を確認した。
- 初回送信は `CUSTOMER_ID` と `CONFIRM_AUTO_REMINDER_SEND=1` を付けた。
- 送信後に `Learning::NotificationLog` の `sent/skipped/failed` を確認した。

## 定期実行設計メモ

### 候補A: systemd timer

EC2運用では systemd timer を推奨する。systemd 管理に寄せると、ログ確認、失敗検知、起動順序、環境変数の扱いを揃えやすい。

メリット:

- `journalctl` で実行ログを追える。
- service と timer を分けられ、手動実行も同じ unit でできる。
- 失敗時の status 確認がしやすい。
- EC2 の systemd/Puma 運用と相性がよい。

デメリット:

- unit/timer 作成には本番サーバー作業が必要。
- Rails の環境変数、working directory、実行ユーザーを正しく合わせる必要がある。
- 複数時刻や顧問別時間を増やす場合は設計を追加する必要がある。

unit例:

```ini
[Unit]
Description=BeMyStyle Learning Auto Reminders

[Service]
Type=oneshot
WorkingDirectory=/var/www/be-my-style/current
Environment=RAILS_ENV=production
Environment=DISABLE_SPRING=1
ExecStart=/bin/bash -lc 'bundle exec rails learning:auto_reminders CONFIRM_AUTO_REMINDER_SEND=1'
User=deploy
```

timer例:

```ini
[Unit]
Description=Run BeMyStyle Learning Auto Reminders every hour

[Timer]
OnCalendar=*-*-* *:05:00
Persistent=true
Unit=bemy-style-learning-auto-reminders.service

[Install]
WantedBy=timers.target
```

send_hour を顧問ごとに使う前提なら、timer は1時間に1回実行し、Rails 側の `auto_reminder_send_hour` で送信対象を絞る運用が分かりやすい。

ログ確認コマンド例:

```bash
sudo systemctl status bemy-style-learning-auto-reminders.timer
sudo systemctl status bemy-style-learning-auto-reminders.service
sudo journalctl -u bemy-style-learning-auto-reminders.service -n 200 --no-pager
```

### 候補B: cron

メリット:

- 設定が単純。
- 既存 cron 運用がある場合に導入しやすい。
- 1日1回だけなら分かりやすい。

デメリット:

- 実行ログや失敗検知を自前で整える必要がある。
- 環境変数、PATH、rbenv/bundler の差異で失敗しやすい。
- 顧問ごとの `send_hour` に合わせて毎時実行する場合、ログローテーションも含めて管理が散らばりやすい。

cron例:

```cron
5 * * * * cd /var/www/be-my-style/current && RAILS_ENV=production DISABLE_SPRING=1 bundle exec rails learning:auto_reminders CONFIRM_AUTO_REMINDER_SEND=1 >> log/learning_auto_reminders.log 2>&1
```

ログ保存例:

```bash
tail -n 200 /var/www/be-my-style/current/log/learning_auto_reminders.log
```

### 結論

EC2運用なら systemd timer 推奨。初回は手動実行だけに留め、十分にログ確認できてから timer を本番に設定する。
