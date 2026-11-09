# 秘密値・本番アクセスのルール

> 2026-11-09、Puma の設定を表示した際に、伏せ字の正規表現が引用符付きの行に効かず、秘密値が作業ログに出た。
> 以後は「値を伏せる」のではなく「出してよい項目だけを出す」構成にしている。詳細は [docs/handover/production_access.md](../../docs/handover/production_access.md)。

## 役割分担

| 作業 | 誰が | 経路 |
|------|------|------|
| 本番の日常確認（稼働・HTTP・設定の有無・権限・疎通・メール件数） | Claude Code | `ssh bms-check status` / `mail` / `connectivity` / `help` だけ |
| 秘密値の登録・変更、Puma 再起動、DB 変更、ログ本文の確認、サーバー設定の変更 | 利用者（管理者） | 利用者が自分のターミナルから管理用キーで SSH |

- Claude Code は管理者作業の**手順を案内するだけ**で、実行しない。
- `bms-check` は SSH の強制コマンドで固定されており、汎用シェル・任意の `sudo`・ファイル転送・ポート転送はできない。

## Claude Code が行わないこと

次は `~/.claude/settings.json` の deny 規則と PreToolUse フック（`~/.claude/hooks/bms-guard.py`）でも機械的に拒否される。
フックに止められたら、言い換えや難読化で回避せず、利用者に作業を依頼する。

- 管理用キー（`~/.ssh/be-my-style.pem`）や `ec2-user` での SSH、`scp` / `sftp` / `rsync`、`ssh -i` / `-S` / `-L` などの鍵・多重化・転送オプション
- 秘密値を含み得るものを丸ごと表示すること
  - systemd の Unit 全体の表示、`systemctl show` の `Environment`
  - `/proc/<pid>/environ`
  - `env` / `printenv` / `export -p` などの環境変数一覧
  - `.env`、`config/master.key`、`rails credentials:show`、`/etc/be-my-style/` 配下
- 秘密値をコマンド引数・URL・ログ・Git に載せること

## 状態の確認方法（許可した項目だけを出す）

| 知りたいこと | Claude Code（`ssh bms-check …`） | 出力例 |
|--------------|----------------------------------|--------|
| Puma・Nginx・歌声分析の稼働、HTTP 応答、デプロイ済みコミット | `status` | `puma_active=active` / `http_root=200` / `deploy_head=…` |
| 秘密値が設定されているか（**空文字は unset 扱い**） | `status` | `config.OPENAI_API_KEY=set` |
| 秘密値ファイルの権限、drop-in に秘密値が残っていないか | `status` | `perm.puma_env=600 root:root` / `dropins_with_secret_names=0` |
| OpenAI・LINE の疎通、Webhook 署名 | `connectivity` | `GET /v1/models -> 200` |
| ビジネス通知の送信成功・失敗の件数（直近 120 分、Rails のログを ec2-user 権限で集計） | `mail` | `mail_log_status=ok` / `sent.business_follow_mail=1` / `failed.business_follow_mail=0` |

- `mail` は `mail_log_status=ok` のときだけ件数を信用する。`partial` はログの一部しか期間をカバーしていない、`unavailable` はログを読めず判定できない（件数は `unknown`）。`0` と `unknown` は別物として扱う。
- `config.<KEY>=set` は「値が 1 文字以上ある」ことを意味する。`OPENAI_API_KEY` の空文字トラップ（キーはあるが値が空）は `unset` として検出できる。
- 管理者が自分で確認するときも、同じ出力を使う: `sudo /usr/local/libexec/bms-status-root status`
- 値そのものが正しいかを確かめたいときは、値を出さずに**長さ**や**疎通結果**で判断する。

## 秘密値の登録・変更（利用者が実施）

```bash
# 本番サーバー上。値は貼り付けても画面・引数・シェル履歴・ログに残らない（2026-11-09 にダミー値で検証済み）
sudo bms-set-secret OPENAI_API_KEY --restart
```

- 書き込み先は `/etc/be-my-style/puma.env`（root 所有・権限 600、Puma は `EnvironmentFile` で読む）。直前の内容は `puma.env.prev`（600）に残る。
- 対象のキーはスクリプト内で固定している。キーを増やすときは `script/ops/bms-check/bms-set-secret` を PR で変更してから、利用者がサーバーに設置する。

## Claude Code がコマンドを書くときの原則

- **出す項目を決める方式（allowlist）**で書く。キー名・有無・長さ・件数・権限・状態コードだけを出す。
- 値を `sed` などで消す方式（denylist）は使わない。書式の揺れ（引用符・空白・複数行）で漏れる。
- 本番で新しい確認項目が必要になったら、`script/ops/bms-check/bms-status-root` に「名前=固定の語彙か数値」の形で追加する PR を作る。サーバーへの設置は利用者が行う。
