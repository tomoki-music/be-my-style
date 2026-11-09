# 本番アクセスの分離（確認専用ユーザー bms-check）

Claude Code などの AI エージェントが本番の秘密値に触れないよう、本番へのアクセスを 2 つに分けています（2026-11-09 導入）。
ルールの要点は [.claude/rules/secrets_rules.md](../../.claude/rules/secrets_rules.md)。

| 経路 | 使う人 | できること |
|------|--------|-----------|
| `ec2-user`（管理用キー） | 利用者（管理者）と GitHub Actions のデプロイ | すべて（`sudo` 可） |
| `bms-check`（確認用キー） | Claude Code | `status` / `mail` / `connectivity` / `help` の固定出力だけ |

## サーバー側の構成

| パス | 所有・権限 | 役割 |
|------|-----------|------|
| `/home/bms-check/.ssh/authorized_keys` | root 644（ディレクトリは root 755） | `restrict,command="/usr/local/sbin/bms-check-shell"` 付きで確認用公開鍵を 1 本だけ登録。シェル・PTY・転送・エージェント転送は不可 |
| `/usr/local/sbin/bms-check-shell` | root 755 | 強制コマンド。`SSH_ORIGINAL_COMMAND` が許可語と完全一致したときだけ実行。それ以外は拒否して `logger -t bms-check` に「拒否（文字数）」だけ記録 |
| `/usr/local/libexec/bms-status-root` | root 755 | root で状態を集め、固定形式で出力。ファイルの中身・ログ本文・秘密値は出さない |
| `/etc/sudoers.d/90-bms-check` | root 440 | `bms-status-root status` / `mail` / `connectivity` の 3 つだけを引数まで固定で許可 |
| `/usr/local/sbin/bms-set-secret` | root 755 | 利用者が秘密値を登録する入力専用スクリプト |
| `/usr/local/sbin/bms-verify-secrets` | root 755 | OpenAI・LINE の疎通を状態コードだけで確認 |
| `/etc/be-my-style/puma.env` | root 600（ディレクトリ 700） | Puma の秘密値。`puma.service.d/secrets.conf` の `EnvironmentFile` で読み込む |

- `bms-check` はパスワードがロックされたユーザーです（`passwd -S` が `LK`）。
- 各ファイルの元は `script/ops/bms-check/` にあります。変更は PR でレビューしてから、利用者がサーバーに設置します。

## Mac（Claude Code）側の構成

- `~/.ssh/config` の `Host bms-check`: `User bms-check`、`IdentityFile ~/.ssh/bms-check`、`IdentitiesOnly yes`、`RequestTTY no`、`ClearAllForwardings yes`。
- `~/.claude/settings.json`
  - `permissions.allow`: `ssh bms-check status|mail|connectivity|help` だけ。
  - `permissions.deny`: `~/.ssh/**` の読み書き、`.env` 系・`config/master.key`・`config/credentials/*.key` の読み取り、`ssh -i`・`ssh ec2-user@`・`scp`・`sftp`・`rsync`・`ssh-add`・`printenv`。
  - `permissions.ask`: Claude Code の設定ファイルとフックの変更（変更には毎回利用者の承認が必要）。
  - `hooks.PreToolUse`（`Bash|Monitor|PowerShell`）: `~/.claude/hooks/bms-guard.py`。管理用キー・`ec2-user@`・本番 IP・`bms-check` 以外での本番接続・ssh の鍵/多重化/転送オプション・`.env`・`master.key`・`/proc/*/environ`・systemd 設定の全表示・環境変数一覧・キーチェーン読み取りを含むコマンドを、実行前に拒否します（フック自体が失敗した場合も拒否）。
- 管理用キー `~/.ssh/be-my-style.pem` には**パスフレーズを設定**し、ssh-agent やキーチェーンには載せない（`ssh-keygen -p -f ~/.ssh/be-my-style.pem`）。GitHub Actions の Secret は別に保存されているため、デプロイには影響しません。

## 既存デプロイへの影響

- GitHub Actions のデプロイ（`rails.yml`）と月次集計（`monthly_singing_ranking_aggregate.yml`）は `ec2-user` と Secret の鍵を使います。`ec2-user`・sshd 設定・既存の sudoers は変更していません。
- `/etc/sudoers.d/90-bms-check` を追加しただけです。設置前に `visudo -cf` で検査し、設置後に新しい接続から `ec2-user` の `sudo -n true` が通ることを確認しました。

## 復旧経路（sudoers・sshd を変更するとき）

1. 変更前に、管理用キーで**別の管理者セッションを 1 本開いたまま**にし、そこで `sudo -n true` が通ることを確認する。
2. 変更は別の接続で行い、sudoers は `sudo visudo -cf <ファイル>` で検査してから設置する。
3. 設置後、**新しい接続**で `sudo -n true` と `systemctl is-active puma` を確認してから、開いていたセッションを閉じる。
4. それでも入れなくなった場合は、AWS コンソールの EC2 Instance Connect（sshd に `AuthorizedKeysCommand` が設定済み）から入って戻す。

## 使い方

```bash
# Claude Code（Mac）
ssh bms-check status        # 稼働・HTTP・デプロイ済みコミット・設定の有無・権限
ssh bms-check mail          # 直近 120 分のメール送信件数・エラー件数
ssh bms-check connectivity  # OpenAI・LINE の疎通、Webhook 署名の正誤

# 利用者（本番サーバー上）
sudo bms-set-secret OPENAI_API_KEY --restart
sudo /usr/local/libexec/bms-status-root status
```

## 2026-11-09 の検証結果

- 許可した 4 操作は固定形式で応答した。
- 任意コマンド、`status; id` などの連結、ファイル読み取り、`bash`、`sudo` の直接実行、`status` への引数追加、PTY、sftp、scp、ポート転送はすべて拒否された（ポート転送はサーバーが `administratively prohibited`）。
- `bms-check` が実行した sudo は、許可した 3 コマンドだけだった。
- `bms-set-secret` をダミー値で疑似端末から実行した。ダミー値は、端末の表示・標準出力・標準エラー、全プロセスの引数（551 回走査）、シェル履歴、root の履歴、journal、`/var/log` 配下のいずれにも現れず、root 600 のファイルにだけ保存された。
- Mac では、ダミーの `.env`・`config/master.key` の読み書きと `~/.ssh` の読み取りが deny 規則で拒否された。管理用キーでの SSH と `.env` を含むコマンドは PreToolUse フックで拒否された。

## 残るアクセス経路（運用で補うもの）

- **管理用キーのファイル**: Claude Code と同じ OS ユーザーで読めるため、パスフレーズ設定で使えないようにする（利用者の操作）。
- **シェル系ツールでの難読化**: フックは文字列照合のため、名前を組み立てるなどの難読化は原理的に検出しきれない。auto mode の分類器が別の層として止めるが、確実な境界は管理用キーのパスフレーズと、本番側の `bms-check` 権限です。
- **書き出したスクリプトの実行**: Write でスクリプトを作って `bash script.sh` で動かすと、フックは中身を見ない。上と同じく、鍵のパスフレーズで防ぐ。
- **`ec2-user` の `NOPASSWD: ALL`**: 管理者とデプロイ用に残している。管理用キーを持つ人は本番のすべてにアクセスできる。
