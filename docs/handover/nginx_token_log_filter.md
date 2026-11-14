# Nginx のアクセスログに招待トークンを残さない設定

NAKAMA のプライベートプロジェクト（PR #244）の招待リンクは `https://be-my-style.com/business/project_invitation?token=…` の形です。
Rails のログでは `token` が `[FILTERED]` と記録されますが、**Nginx のアクセスログは URL のクエリをそのまま記録する**ため、この手順で伏せます。

- 設定ファイル: [config/nginx/bms_token_log_filter.conf](../../config/nginx/bms_token_log_filter.conf)
- 動作の検証: [script/nginx_token_log_filter_check.sh](../../script/nginx_token_log_filter_check.sh)。CI の「Nginx token log filter」で、使い捨ての nginx を起動して確かめます。
- 本番の作業は管理者（利用者）が自分の端末から行います。Claude Code が使えるのは `ssh bms-check` だけです。

## 何が変わるか

| 項目 | 内容 |
|---|---|
| 伏せる対象 | クエリに `token` / `confirmation_token` / `reset_password_token` / `unlock_token` のどれかを含む要求。招待リンクに加えて、Devise の確認メールとパスワード再設定のリンクも対象です |
| 伏せ方 | パスは残し、クエリ全体を `?[FILTERED]` に置き換える（例: `GET /business/project_invitation?[FILTERED]`） |
| Referer | 上と同じ条件で伏せる |
| そのまま残る項目 | 上記以外の URL・状態コード・IP・User-Agent など。並びは既定の `main` 形式と同じです |
| アプリ側の対策（PR #244） | トークン付きの URL は必ずすぐにトークンの無い URL へリダイレクトします（画面を描かず `Referrer-Policy: no-referrer` を付ける）。そのため、トークンがアクセスログに出るのは、最初の1回の要求行だけです |

## 実施するタイミング

**PR #244 をマージする前**に設定してください。そうすれば、本物の招待トークンは一度もアクセスログに載りません。マージ後に設定する場合は、下の「既存のログに記録されたトークンの扱い」も行ってください。

## 1. 事前確認（読み取りだけ）

```bash
sudo nginx -v
# 設定ファイルの場所と、log_format・access_log・include の行を確認する(設定全体は出さない)
sudo nginx -T 2>/dev/null | grep -nE '^# configuration file|^\s*(log_format|access_log|include)\b'
ls -l /var/log/nginx/
cat /etc/logrotate.d/nginx
# ログをほかへ送っていないか(動いていれば、送り先にも同じ対応が必要)
systemctl is-active amazon-cloudwatch-agent 2>/dev/null || true
```

確認すること:

- `/etc/nginx/nginx.conf` の `http { … }` の中にある `access_log /var/log/nginx/access.log main;` の行（AL2023 の既定）。
- `conf.d` などの `server { … }` に、ほかの `access_log` の行が無いか。
  - 書式名の無い `access_log …;` は `combined` 形式になり、URL をそのまま記録します。この行も手順 3 の対象です。
  - `access_log off;` はそのままで構いません。

## 2. バックアップ

```bash
sudo cp -a /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak-token-filter
# 手順1で access_log の行があった server 側の設定ファイルも同じように控える(例)
# sudo cp -a /etc/nginx/conf.d/be-my-style.conf /etc/nginx/conf.d/be-my-style.conf.bak-token-filter
```

## 3. 設置

1. 設定ファイルをサーバーへ置きます（`conf.d` の外に置き、二重に読み込まれないようにします）。

   ```bash
   # 手元(リポジトリ)から、普段の管理用 SSH でサーバーへ送る
   scp config/nginx/bms_token_log_filter.conf ec2-user@be-my-style.com:/tmp/
   # サーバー上で
   sudo install -m 644 -o root -g root /tmp/bms_token_log_filter.conf /etc/nginx/bms_token_log_filter.conf
   rm /tmp/bms_token_log_filter.conf
   ```

2. `nginx.conf` の `http` の中にある既存の `access_log` 行を、このファイルの `include` に置き換えます。

   ```bash
   sudo sed -i 's#^\(\s*\)access_log\s\+/var/log/nginx/access.log\s\+main;#\1include /etc/nginx/bms_token_log_filter.conf;#' /etc/nginx/nginx.conf
   grep -nE 'bms_token_log_filter|access_log' /etc/nginx/nginx.conf
   ```

   `include /etc/nginx/bms_token_log_filter.conf;` が1行だけ表示され、`/var/log/nginx/access.log` 向けの `access_log` 行が残っていなければ成功です。
   - 行の書き方が違って置き換わらなかった場合は、エディタで直接書き換えてください。
   - `access_log` は同じ場所に2つあると両方に記録されます。そのため、元の行は必ず置き換えます（並べて追加しない）。

3. 手順1で `server` 側に `access_log` の行があった場合は、その行の末尾の書式名（`main`、または書式名なし）を `bms_filtered` にします。

   例: `access_log /var/log/nginx/access.log bms_filtered;`

## 4. 検証

```bash
sudo nginx -t
```

`syntax is ok` と `test is successful` の両方が出てから、反映します。`reload` は接続を切らずに設定を読み直します。本番のサービス操作なので、実施する人の判断で行ってください。

```bash
sudo systemctl reload nginx
systemctl is-active nginx
```

反映後に、ダミーの値で確かめます（本物のトークンは使わない）。

```bash
curl -s -o /dev/null -w '%{http_code}\n' 'https://be-my-style.com/business/project_invitation?token=BMSLOGCHECK123'
curl -s -o /dev/null -w '%{http_code}\n' 'https://be-my-style.com/business/help?bmscheck=1'
sudo tail -n 50 /var/log/nginx/access.log | grep -c BMSLOGCHECK123         # → 0
sudo tail -n 50 /var/log/nginx/access.log | grep 'project_invitation?\[FILTERED\]'  # → 1行以上
sudo tail -n 50 /var/log/nginx/access.log | grep 'bmscheck=1'               # → そのまま残る
curl -sI https://be-my-style.com/ | head -1                                   # → 200 など、普段どおり
```

- マージ前は `/business/project_invitation` がまだ存在しないため、状態コードは 404 またはログインへの転送です。確かめたいのはログの記録だけなので、問題ありません。
- PR #244 のデプロイ後にも同じ確認を1回行い、Rails のログ（アプリの `log/production.log`）でも `token=[FILTERED]` になっていて、`BMSLOGCHECK123` が 0 件であることを確かめてください。

## 5. 切り戻し

```bash
sudo cp -a /etc/nginx/nginx.conf.bak-token-filter /etc/nginx/nginx.conf
# server 側を変更した場合は、そのファイルも .bak-token-filter から戻す
sudo nginx -t && sudo systemctl reload nginx
```

- `/etc/nginx/bms_token_log_filter.conf` は、どこからも読み込まれなくなるので残しても動作に影響しません。不要なら削除します。
- 切り戻した後は、招待トークンが再びアクセスログに記録されます。PR #244 がリリース済みなら、原因を直して再設置するまでの間に記録されたトークンを、下の手順で無効にしてください。

## 既存のログに記録されたトークンの扱い

### 確認（読み取りだけ）

```bash
P='[?&](token|confirmation_token|reset_password_token|unlock_token)='
sudo grep -cE "$P" /var/log/nginx/access.log /var/log/nginx/error.log
sudo sh -c "zgrep -cE '$P' /var/log/nginx/*.gz 2>/dev/null" | grep -v ':0$'
# 招待リンクだけの件数
sudo sh -c "zgrep -c 'project_invitation?token=' /var/log/nginx/access.log* 2>/dev/null"
```

### 招待トークン（`/business/project_invitation?token=`）

- PR #244 をマージする前に設定すれば、**本物の招待トークンは存在しません**（件数は 0 になるはずです。手順4のダミー値はこの設定の後に送るので、伏せられて残りません）。
- 記録が見つかった場合（設定前にリリースした・切り戻した期間がある）は、**招待リンクを再発行または無効化**してください。
  - DB に入っているのはトークンのダイジェストだけで、無効化・再発行したリンクは、登録途中の人を含めて参加に使えなくなります。そのため、ログに残ったトークンは無害になります。
  - 画面から行う場合: 各プライベートプロジェクトの「招待リンク」画面で、「再発行する」または「このリンクを無効にする」を押します（システム管理者・コミュニティのオーナー）。
  - まとめて行う場合（本番 DB の更新なので、実施する人の判断で行ってください。参加済みのメンバーには影響しません）:

    ```bash
    # 件数の確認(読み取りだけ)
    DISABLE_SPRING=1 RAILS_ENV=production bundle exec rails runner 'puts ProjectInvitationLink.not_revoked.where("expires_at > ?", Time.current).count'
    # 有効なリンクをすべて無効化する(各プロジェクトで必要なら再発行してもらう)
    DISABLE_SPRING=1 RAILS_ENV=production bundle exec rails runner 'puts ProjectInvitationLink.not_revoked.update_all(revoked_at: Time.current, updated_at: Time.current)'
    ```

### Devise の確認メール・パスワード再設定のトークン（この設定の前から記録されているもの）

- 確認メールのリンクは1日（`confirm_within`）、パスワード再設定のリンクは Devise の期限を過ぎると使えません。そのため、古いログに残っている値の多くはすでに無効です。
- 設定した日から1日程度は、念のため不審な確認・再設定の操作が無いか、Rails のログで確かめてください。

### ログから消す場合（任意）

ログを書き換えると監査の記録も変わります。必要な場合だけ行い、元のファイルは別の安全な場所へ控えてください。

```bash
P='s#([?&])(token|confirmation_token|reset_password_token|unlock_token)=[^ "&]*#\1\2=[FILTERED]#g'
# 書き込み中のファイル(sed -i は新しいファイルに置き換わるため、直後に Nginx へログを開き直させる)
sudo sed -i -E "$P" /var/log/nginx/access.log /var/log/nginx/error.log
sudo nginx -s reopen
# ローテート済みの圧縮ファイル(ファイル名は手順1の ls で確認)
for f in /var/log/nginx/access.log-*.gz; do
  sudo sh -c "zcat '$f' | sed -E '$P' | gzip > '$f.tmp' && mv '$f.tmp' '$f'"
done
```

- `error.log` は書式を変えられません。上流（Puma）の停止中などのエラーでは要求行がそのまま記録されることがあるため、確認と削除の対象に含めています。
- CloudWatch などへログを送っている場合は、送り先に残ったログも同じ基準で確認してください。
