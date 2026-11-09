# ビジネス通知メールの送信元切り替え（info@be-my-style.jp / XServer）

ビジネス（NAKAMA）の通知メールだけを、Gmail SMTP から XServer SMTP（`info@be-my-style.jp`）に切り替える手順です。
コードは `BUSINESS_MAIL_SENDER_ENABLED="true"` を設定するまで何も変えません。マージしただけでは送信元は変わりません。

## 対象と対象外

| 区分 | メール | 送信元・経路 |
|------|--------|--------------|
| 対象 | `CustomerMailer` の `like_post_mail` / `comment_post_mail` / `business_follow_mail` / `business_request_mail` / `business_accept_mail` / `business_project_created_mail` / `business_project_joined_mail` / `business_project_chat_mail` | 有効化後は `管理人より <info@be-my-style.jp>`、XServer SMTP |
| 対象外 | Devise（ログイン認証・パスワード再設定・確認メール）、音楽（MMM）のイベント・コミュニティ通知、締め切りリマインド、エントリー依頼、学習、管理者通知、`ContactMailer` | 従来どおり（共通の Gmail SMTP 設定） |

- 実装: `app/services/business_mail/sender_config.rb`、`CustomerMailer#business_mail`。
- 共通の `config.action_mailer.smtp_settings`（Gmail）に、ビジネス通知のときだけ XServer の値をメール単位で上書きします（`delivery_method_options`）。
- 宛先・件名・本文・送信条件・`deliver_later` の実行方式は変更していません。`Reply-To` はもともと設定されていないため、付けていません（返信は `info@be-my-style.jp` に届きます）。

## 現状の送信経路（調査結果）

- 本番の ActionMailer: `config/environments/production.rb` で `smtp.gmail.com:587`（STARTTLS、`openssl_verify_mode: 'none'`）を使用。認証情報は `Rails.application.credentials.gmail[:user_name]` / `[:password]`。
- `ApplicationMailer` の `default from` は `管理人より<from@example.com>`。Gmail SMTP は From を認証アカウントのアドレスに書き換えるため、受信者には Gmail アドレスが送信元として表示されていると考えられます。
- Devise の `mailer_sender` も `credentials.gmail[:user_name]`。
- 旧 Gmail アドレスの用途: SMTP 認証ユーザー（credentials 経由）、Devise の送信元（同じ値）、Gmail による書き換え後の実質的な From。コードに直接書かれているのは、歌声の登録画面のお問い合わせ先の文言（`app/controllers/singing/registrations_controller.rb`）だけで、通知の宛先には使われていません（管理者通知の宛先は DB の `Admin#email`）。
- ジョブ: 本番の `queue_adapter` は未設定（Rails 既定の `:async`）。ビジネス通知はすべて `deliver_later` で、Puma ワーカー内で送信されます。そのため ENV は Puma プロセスの値を使い、変更後は Puma の再起動が必要です。

## 公開 DNS で確認できたこと（2026-11-09 時点）

| 項目 | 値 | 判断 |
|------|----|------|
| NS | `ns1〜ns5.xserver.jp` | DNS は XServer で管理 |
| MX | `0 be-my-style.jp.`（A: 85.131.213.105） | XServer で受信する構成 |
| SPF | `v=spf1 +a:sv16724.xserver.jp +a:be-my-style.jp +mx include:spf.sender.xserver.jp ~all` | XServer からの送信は許可済み |
| DKIM | `default._domainkey.be-my-style.jp` に公開鍵あり | XServer の DKIM が有効と思われる（署名が実際に付くかは受信テストで確認） |
| DMARC | `_dmarc.be-my-style.jp` に **レコードなし** | 未設定 |
| SMTP | `sv16724.xserver.jp:465` は接続開始時から TLS、証明書 `CN=*.xserver.jp` の検証 OK | 465 番で使える |

## 本番に入れる設定（値はここに書かない）

既存の本番シークレットのうち、ENV で渡しているもの（`OPENAI_API_KEY` など）と同じく、Puma の systemd で渡します。
パスワードは `systemctl show` で他のユーザーから見えないよう、権限 600 の `EnvironmentFile` に置くことを推奨します。

| 設定名 | 用途 | 必須 |
|--------|------|------|
| `BUSINESS_MAIL_SENDER_ENABLED` | `true`（厳密一致）のときだけ切り替える。切り戻しはこれを外す | 必須 |
| `BUSINESS_SMTP_ADDRESS` | XServer サーバーパネルの SMTP ホスト名（現状 `sv16724.xserver.jp` と思われる。サーバーパネルで要確認） | 必須 |
| `BUSINESS_SMTP_PORT` | 省略時 465（接続開始時から TLS）。587 を指定すると STARTTLS 必須 | 任意 |
| `BUSINESS_SMTP_USER_NAME` | SMTP 認証ユーザー（XServer のメールアカウント名 = メールアドレス） | 必須 |
| `BUSINESS_SMTP_PASSWORD` | 上記メールアカウントのパスワード | 必須 |

- `ENABLED=true` でも必須値が空（空文字・空白だけを含む）なら、通知を止めずに従来の Gmail 経路で送り、欠けた**キー名だけ**を `[BusinessMail::SenderConfig]` の warn ログに出します。
- 証明書は検証します（`openssl_verify_mode: "peer"`）。ホスト名は証明書と一致する `sv*****.xserver.jp` を使ってください（独自ドメインのホスト名だと検証に失敗します）。

## 本番切り替え手順

### 1. XServer 側の確認（サーバーパネル）

1. 「メール」→「メールアカウント設定」→ ドメイン `be-my-style.jp` を選び、`info@be-my-style.jp` があるか確認する。無ければ作成する。容量・パスワードを控える（パスワードは共有しない）。
2. 同じ画面の「メールソフト設定」（または「アカウント情報」の「サーバー情報」）で、SMTP サーバー（ホスト名）とポートを確認する。
3. 「メール」→「DKIM設定」で `be-my-style.jp` が「ON」になっているか確認する。
4. 「DNSレコード設定」→ `be-my-style.jp` で、MX と SPF（`include:spf.sender.xserver.jp`）、`default._domainkey` があることを確認する。
5. （推奨）DMARC を追加する。最初は監視だけの設定から始める:
   `_dmarc.be-my-style.jp TXT "v=DMARC1; p=none; rua=mailto:info@be-my-style.jp"`
   XServer の「DMARC設定」が使えるならそこから設定する。数週間レポートを見て問題がなければ `p=quarantine` を検討する。
6. 返信を受けるため、Webメール（またはメールソフト）で `info@be-my-style.jp` の受信箱にログインできること、外部（自分の Gmail など）から送ったメールが届くことを確認する。
7. 送信数の上限（XServer は 1 アカウントあたりの時間・日あたりの送信数に制限あり）を確認し、ビジネス通知の送信量が収まるか確認する。

### 2. コードのデプロイ

1. この PR をレビュー → main にマージ（自動デプロイ）。JST 02:00〜06:00 は EC2 が停止しているので避ける。
2. この時点では `BUSINESS_MAIL_SENDER_ENABLED` が無いので、挙動は変わらない。

### 3. 本番設定の追加（ユーザーが実施）

```bash
# 本番サーバー上。値は対話的に入力し、コマンド履歴に残さない。
sudo install -d -m 700 -o root -g root /etc/be-my-style
sudo install -m 600 -o root -g root /dev/null /etc/be-my-style/business_mail.env
sudo vi /etc/be-my-style/business_mail.env
#   BUSINESS_MAIL_SENDER_ENABLED=true
#   BUSINESS_SMTP_ADDRESS=<サーバーパネルのホスト名>
#   BUSINESS_SMTP_PORT=465
#   BUSINESS_SMTP_USER_NAME=<メールアカウント>
#   BUSINESS_SMTP_PASSWORD=<パスワード>

# Puma の Unit に EnvironmentFile を追加（drop-in）
sudo systemctl edit puma
#   [Service]
#   EnvironmentFile=/etc/be-my-style/business_mail.env

sudo systemctl daemon-reload
sudo systemctl restart puma
sudo systemctl status puma
sudo journalctl -u puma -n 50 --no-pager
```

値が入っているかは長さだけで確認する（値は出さない）:

```bash
puma_pid=$(sudo systemctl show puma --property=MainPID --value)
for k in BUSINESS_MAIL_SENDER_ENABLED BUSINESS_SMTP_ADDRESS BUSINESS_SMTP_PORT BUSINESS_SMTP_USER_NAME BUSINESS_SMTP_PASSWORD; do
  v=$(sudo cat /proc/$puma_pid/environ | tr '\0' '\n' | grep "^$k=" | cut -d= -f2-)
  echo "$k length=${#v}"
done
```

### 4. 自分宛てに 1 通送って確認

実ユーザーに送らないよう、自分の 2 アカウント（例: 自分のテスト用 Business アカウント A と B）の間で、**フォロー**（`business_follow_mail`）を 1 回だけ行うのが一番簡単です。A で B のプロフィールを開いてフォローすると、B のメールアドレスに 1 通届きます（B のマイページでメール通知（`confirm_mail`）がオンであること。すでにフォロー済みなら一度解除してからフォローする）。

受信側（Gmail の場合）で確認すること:

1. メールを開き「︙」→「メッセージのソースを表示」。
2. `From: 管理人より <info@be-my-style.jp>`（日本語の表示名はエンコードされて表示される）。
3. 「SPF: PASS」「DKIM: 'PASS'（ドメイン be-my-style.jp）」「DMARC: 'PASS'」（DMARC 未設定なら表示なし）。
4. `Authentication-Results:` ヘッダーに `spf=pass smtp.mailfrom=be-my-style.jp`、`dkim=pass header.i=@be-my-style.jp`、（設定後は）`dmarc=pass` があること。
5. 迷惑メールフォルダに入っていないこと。
6. そのメールに返信し、`info@be-my-style.jp` の受信箱に届くこと。

あわせて、対象外のメールが変わっていないことを確認する（例: パスワード再設定を自分のアドレスで実行し、従来の送信元のままであること）。

ログ確認:

```bash
sudo journalctl -u puma -n 300 --no-pager | grep -i "BusinessMail::SenderConfig\|business_follow_mail\|Net::SMTP\|OpenSSL"
```

`設定不足のため従来の送信経路を使用` が出ていたら、表示されたキー名の値が空になっています。

### 5. 切り戻し

コードを戻す必要はありません。

```bash
sudo vi /etc/be-my-style/business_mail.env   # BUSINESS_MAIL_SENDER_ENABLED を削除、または false に
sudo systemctl restart puma
sudo journalctl -u puma -n 50 --no-pager
```

再起動後のビジネス通知は従来の Gmail 経路に戻ります。再起動前に積まれていた `deliver_later` のジョブは、`:async` のため Puma 再起動で失われます（従来と同じ制約）。DNS（SPF/DKIM）の設定は残しても Gmail 経路には影響しません。

## 未確認事項

- `info@be-my-style.jp` のメールボックスが作成済みか、パスワード、XServer の送信数上限。
- 実際の SMTP ホスト名（SPF に `sv16724.xserver.jp` があるので同じサーバーと推定）。
- DKIM 署名が実際に付くか（DNS に公開鍵はある）。
- 本番 Puma の systemd Unit で、既存の ENV をどの方法（`Environment=` か `EnvironmentFile=`）で渡しているか。上の手順は drop-in で追加する前提。
- 本番 EC2 から `sv16724.xserver.jp:465` へ外向きに接続できるか（AWS は通常 25 番だけを制限。セキュリティグループ・NACL の outbound で要確認）。
  確認コマンド（ログインはしない）: `echo QUIT | openssl s_client -connect sv16724.xserver.jp:465 -verify_return_error 2>&1 | grep "Verify return code"`
- 旧 Gmail アドレスは Devise・音楽通知などで引き続き使われます。歌声の登録画面のお問い合わせ先文言も旧アドレスのままです。
