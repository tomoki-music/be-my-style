# イベント締め切り自動リマインド

イベントの「曲リクエスト締め切り」「エントリー締め切り」の **指定時間前（初期値12時間・1〜168時間）** に、開催コミュニティのメンバーへお知らせを自動送信する機能。本文は自動生成のほか、主催者が編集できる。

> ⚠️ 本番 EC2 への cron 登録・SSH 作業は **必ずユーザー確認後** に実施すること。

## 設定（主催者・管理者）

- 公開画面: イベント作成 / 編集画面の「締め切り自動リマインド」欄（`can_create_event?` / `can_edit_event?` を持つ人だけが開ける既存画面）
- 管理画面: `/admin/events/:id/edit` の同じ欄
- 締め切り種別ごとに「有効/無効」「配信方法（メール / コミュニティチャット）」「締め切りの［N］時間前に送信」「送信メッセージ（本文）」を設定する
- 送信予定日時（JST）、状態（無効 / 未送信（送信予定）/ 未送信（自動送信しません）/ 送信中 / 送信済み / 失敗）、送信メッセージのプレビューを表示する
- 入力を変えると、保存前でも送信予定日時・状態・プレビューが更新される（`POST /public/events/:id/deadline_reminder_preview`、作成中は `POST /public/events/deadline_reminder_preview`、管理画面は `/admin/events/...` の同名パス）。プレビューAPIは表示用HTMLを返すだけで、保存・送信はしない。権限は編集（作成）画面と同じ before_action（`authorize_event_edit!` / `authorize_event_creation!` / `authenticate_admin!`）で、権限がなければ 403（JSON）
- 初期状態は無効。既存イベントにはリマインド行が無いため、導入直後の一斉送信は起きない
- 締め切りが未設定の種別は有効化できない（有効なまま締め切りを消すこともできない）

## 送信タイミング

- 送信予定日時 = 締め切り日時 − `lead_hours` 時間（種別ごと。初期値 12、整数 1〜168）。Asia/Tokyo 基準
- `lead_hours` は空欄・0・負数・小数・169以上・数字以外をサーバー側で拒否する（小数は integer 変換で丸められるため、変換前の値で検証する）。入力エラー時も入力値・本文は画面に残る
- 既存の締め切り（`event_entry_deadline` / `request_deadline`）は日時カラムで、受付終了判定も `締め切り <= 現在時刻`（`Event#status_key`）なので、その日時をそのまま使う
- 定期実行は **5分ごと**（cron 想定）。送信予定から最大5分程度遅れる
- 次の条件をすべて満たしたときだけ送る（`EventDeadlineReminders::Eligibility`）
  - 有効、締め切りあり、未送信（pending）
  - 送信予定日時 ≤ 現在 < 締め切り
  - イベント開始前
  - **armed**: 有効化・締め切り変更・送信タイミング変更の時点で送信予定がまだ未来だった（`armed_deadline` / `armed_scheduled_at` が現在の締め切り・送信予定日時と一致）
- 何が変わったかの判定は `Event#deadline_reminder_schedule_change` に共通化（有効化 > 締め切り > 送信タイミングの順）。保存時（`after_save`）とプレビュー（保存前の値）で同じ判定を使う

| ケース | 挙動 |
|---|---|
| 定期処理が止まって予定を過ぎた | 締め切り前なら次回実行で送る（armed のまま） |
| 予定を過ぎてから有効化 | 自動送信しない。画面に理由を表示 |
| 締め切り変更で予定が未来 | 新しい予定日時に追従 |
| 締め切り変更で予定が過去 | 自動送信しない。画面に理由を表示 |
| 送信タイミング変更で予定が未来 | 新しい予定日時に追従 |
| 送信タイミング変更で予定が過去 | 自動送信しない（即送信しない）。「送信予定日時を過ぎているため、自動送信されません」と理由を表示 |
| 本文だけの変更 | 送信予定は維持（予定を過ぎた後の復旧送信の対象からも外れない） |
| 送信済み・失敗後の締め切り変更 / 配信方法切り替え / 送信タイミング・本文の変更 | 自動再送しない（手動再送機能なし）。画面に「変更しても再送されません」と表示 |
| 送信中の変更 | 送信タイミング・配信方法・本文はサーバー側で拒否（画面でも入力欄を無効化）。無効化（中断）だけはできる |
| 無効化 | 送らない。メール送信中に無効化されたら残りを中断 |

イベントに「非公開」「開催中止」を表すカラムは無い。削除されたイベントはリマインドも `dependent: :destroy` で消える。

> 本番 EC2 は JST 02:00〜06:00 に自動停止する。その時間帯が送信予定のもの（締め切りが 14:00〜18:00）は、06:00 以降の最初の実行で送られる。

## 送信メッセージ

- 件名は常に自動生成。本文は `custom_message`（種別ごと、最大5,000文字）が空なら従来テンプレートで自動生成、あればその文章を使う
- 前後の空白（全角スペースを含む）を除き、空白だけの入力は未設定（自動生成）として扱う。改行は LF に揃えて保持する
- 本文の後ろに **共通フッター**（「▼イベント詳細・エントリー（リクエスト）はこちら」＋イベント詳細の絶対URL）を必ず付ける。主催者が本文からURLを消しても参加ページへ進める。自動生成文の本文部分にはURLを含めず、フッターと重複しない。編集欄にはフッターを含めない
- 画面の「自動生成文を編集欄に入れる」は、保存前の入力内容で作った自動生成文のコピー。その後イベント名や日時を変えても編集欄は自動更新されない（画面に説明あり）。「自動生成に戻す」は編集欄を空にする（保存して確定）
- プレーンテキストとして扱う。メールは HAML でエスケープし改行を `<br>` にする。チャットは Markdown 記号をエスケープして文字のまま表示し（URL だけは自動リンクのためエスケープしない）、HTML は `Chat::MarkdownRenderer` の filter_html / Sanitize で無害化する
- プレビューには配信方法、メールなら件名と共通フッター、チャットなら実際の投稿と同じ描画結果を表示する。生成は送信と同じ `EventDeadlineReminders::MessageBuilder`

## 配信中の内容の確定

- 配信開始時（確保後の最初の処理）に件名・本文・チャット本文・配信方法・送信タイミングを `message_snapshot`（JSON）に保存し、メールの全受信者・停止後の引き継ぎ実行はこの内容で送る。送信中に設定が変わっても受信者ごとに内容・配信方法が混在しない
- 確保後の再確認で送れず未送信へ戻す場合は `message_snapshot` を破棄する（次回は最新の設定で作る）
- 退会・受信設定OFF・コミュニティ退会などの配信対象条件は、従来どおり受信者ごとに送信直前に確認する
- 送信済み・失敗の画面表示には、送った内容（スナップショット）と「N時間前の設定・編集した本文/自動生成の本文」を表示する

## 配信対象

### メール

開催コミュニティの `CommunityCustomer`（＝参加承認済み）のうち、退会していない・メール確認済み（`confirmed_at`）・メール受信設定 ON（`confirm_mail`）・有効なメールアドレスを持つ人。イベントへの参加登録の有無は問わない。

- 1通 = 1受信者（To のみ。CC/BCC を使わない）
- 一覧取得時に加えて、送信直前にも受信者ごとに条件を再確認する
- 非本番環境では実送信しない（`EVENT_DEADLINE_REMINDER_ALLOW_REAL_EMAILS` を設定した場合だけ送る。test は `delivery_method=:test`）

### コミュニティチャット

- 開催コミュニティのチャットへ1件だけ投稿する（オーナーが参加しているルーム = 参加承認時と同じ判定）
- `chat_messages.system_generated = true` で作成し、画面に「🔔 自動お知らせ」バッジを出す。本文の編集は不可
- 投稿者名義はイベント主催者（退会済み・コミュニティ外ならコミュニティオーナー）
- 投稿後、投稿者以外のメンバーへアプリ内通知（`group_chat`）を作る。通常のチャット投稿で送られる「チャット投稿メール」は送らない（メール配信方式との二重通知を避けるため）

## 重複送信の防止

- `event_deadline_reminders` は (event_id, kind) 一意。1イベント×1種別=1行
- 条件付き UPDATE（`pending → sending`）でリマインドを確保できたプロセスだけが処理する
- `sending` のまま 15分（`STALE_SENDING_AFTER`）進捗がないものだけ、次の実行が引き継ぐ（メール送信中は受信者ごとに `started_at` を更新）。引き継ぎは締め切り後・無効化後でも行い、送れない状態なら結果を確定する（送信中のまま残さない）
- メールは送信前に `event_deadline_reminder_deliveries`（(reminder_id, customer_id) 一意）を作り、成功で `delivered`、失敗で `failed` にする
- チャットは行ロック内で未投稿を確認し、投稿作成と `sent` への更新を同一トランザクションで行う

## 失敗・中断時の扱い

| 状況 | 記録 | 自動再送 |
|---|---|---|
| 1人への送信で SMTP がエラー応答（認証・4xx/5xx）／接続不可 | その受信者だけ `failed`、理由の先頭が `[未送信確定]` | しない。他の受信者の送信は続ける |
| 本文組み立て（テンプレート）で失敗 | その受信者だけ `failed` `[未送信確定]` | しない |
| 応答待ちタイムアウト・接続断など | その受信者だけ `failed` `[結果不明]` | しない（届いている可能性があるため） |
| 送信後・DB更新前にプロセス停止 | 引き継ぎ時に `failed` `[結果不明]` | しない |
| 全受信者が失敗 | リマインド自体が `failed` | しない |
| 想定外の例外（DB障害など） | そのリマインドだけ `failed`、送信中だった受信者は `[結果不明]`。他のイベントの処理は続ける | しない |
| チャットのルーム・投稿者が見つからない | `failed`（投稿はしていないことが確実） | しない |
| プロセス停止で `sending` のまま | 15分後の定期実行で引き継ぐ。締め切り前なら未処理の受信者へ送る。締め切り後・無効化後なら、途中まで送っていれば `sent`、何も送っていなければ `pending` に戻す | 結果不明の受信者にはしない |

### 現在の制約

- 未送信が確実な失敗（`[未送信確定]`、チャットの `failed`）も自動では再試行しない。SMTP 設定ミスなどが原因の場合、締め切りまで5分ごとに失敗を繰り返すことになるため。再送機能もないので、原因を直したうえで、主催者がイベントページやチャットから手動で案内する
- `failed` から `pending` へ戻す操作は再送と同じ意味になるため、運用手順には含めない

### 確認方法（read-only）

```bash
cd /home/ec2-user/be-my-style
RAILS_ENV=production DISABLE_SPRING=1 ~/.rbenv/shims/bundle exec rails event_deadline_reminders:status
```

- `due_now`: 次回の定期実行で送信対象になりうる件数
- `sending ... STALE`: 15分以上止まっている。次回の定期実行で自動的に引き継ぐ
- `failed`: 理由つきの最新20件
- `failed_deliveries not_sent / unknown`: 受信者単位の失敗の内訳
- イベント編集画面の状態欄でも「送信中（停止の可能性）」「失敗」と理由を確認できる

## 送信タイミング・本文編集の導入（2026-10 追加分）

- マイグレーション `20261018000000_add_lead_hours_and_custom_message_to_event_deadline_reminders` 1件
  - `lead_hours`（integer, NOT NULL, default 12）、`custom_message`（text）、`armed_scheduled_at`（datetime）、`message_snapshot`（text）を追加
  - 既存行は 12時間・本文未設定（自動生成）になる。`armed_deadline` がある行だけ `armed_scheduled_at = armed_deadline − 12時間` を記録する。`enabled` / `status` / 送信済み情報は変更しない
- cron（`bin/run_event_deadline_reminders`、5分ごと）の変更は不要
- 反映順: マージ → CI/CD（migrate → precompile → Puma 再起動）。migrate 前に新コードの cron が動くとその回だけ失敗するが、次の5分後の実行で回収される
- 反映後の確認（read-only）: `rails event_deadline_reminders:status`（`due_now` / `upcoming` に `lead_hours` が出る）

## 本番の定期実行設定（2026-10-17 登録済み）

cron 用スクリプト: `bin/run_event_deadline_reminders`（`EventDeadlineReminders::DispatchJob.perform_now` を rails runner で同期実行する）

```cron
*/5 * * * * APP_ROOT=/home/ec2-user/be-my-style /home/ec2-user/be-my-style/bin/run_event_deadline_reminders >> /home/ec2-user/be-my-style/log/cron_event_deadline_reminders.log 2>&1
```

導入手順:

1. PR マージ → デプロイ後、`RAILS_ENV=production bundle exec rails db:migrate`（マイグレーション3件）
2. 登録前に対象が0件であることを確認する（既存イベントは全て無効のため 0 件のはず）

```bash
RAILS_ENV=production DISABLE_SPRING=1 bundle exec rails runner 'puts EventDeadlineReminder.where(enabled: true).group(:kind, :channel, :status).count'
```

3. crontab に上記を追加し、ログに `finish exit_status=0` が出ることを確認する

## 確認コマンド（read-only）

```bash
# リマインドの状態
RAILS_ENV=production DISABLE_SPRING=1 bundle exec rails runner 'EventDeadlineReminder.order(updated_at: :desc).limit(20).each { |r| puts [r.id, r.event_id, r.kind, r.enabled, r.channel, r.status, r.scheduled_at&.in_time_zone("Asia/Tokyo"), r.delivered_count, r.failed_count, r.failure_reason].inspect }'

# 受信者単位の結果
RAILS_ENV=production DISABLE_SPRING=1 bundle exec rails runner 'puts EventDeadlineReminderDelivery.where(event_deadline_reminder_id: 123).group(:status).count'
```

## 停止方法

- 個別: イベント編集画面で該当の自動リマインドを無効にする
- 全体: crontab の該当行をコメントアウトする

## 制約・注意点

- 自動生成文はテンプレート（外部生成AIは使わない）。イベント説明（introduction）は含めない
- メールは cron プロセス内で1人ずつ同期送信する（Gmail SMTP の送信上限に注意）
- 手動再送機能は無い。`failed` になった場合は原因を確認し、必要なら主催者が手動で案内する
