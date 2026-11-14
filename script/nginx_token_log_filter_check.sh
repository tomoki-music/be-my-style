#!/usr/bin/env bash
# config/nginx/bms_token_log_filter.conf を実際の nginx で検証する(CI・使い捨ての環境用。本番では実行しない)。
# 一時ディレクトリに最小の nginx.conf を作り、設定ファイルを include して起動 → 要求を送り → アクセスログを確かめる。
set -euo pipefail

CONF_SRC="$(cd "$(dirname "$0")/.." && pwd)/config/nginx/bms_token_log_filter.conf"
WORK="$(mktemp -d)"
trap 'nginx -e "$WORK/logs/error.log" -p "$WORK" -c "$WORK/nginx.conf" -s stop 2>/dev/null || true; rm -rf "$WORK"' EXIT
mkdir -p "$WORK/logs" "$WORK/tmp"

# 本番の設置先(/var/log/nginx/access.log)を一時ディレクトリへ差し替えて読み込む。
sed "s#/var/log/nginx/access.log#$WORK/logs/access.log#" "$CONF_SRC" > "$WORK/bms_token_log_filter.conf"
cat > "$WORK/nginx.conf" <<CONF
pid $WORK/nginx.pid;
error_log $WORK/logs/error.log;
events {}
http {
  client_body_temp_path $WORK/tmp/body;
  proxy_temp_path $WORK/tmp/proxy;
  fastcgi_temp_path $WORK/tmp/fastcgi;
  uwsgi_temp_path $WORK/tmp/uwsgi;
  scgi_temp_path $WORK/tmp/scgi;
  include $WORK/bms_token_log_filter.conf;
  server {
    listen 127.0.0.1:18080;
    location / { return 200 "ok"; }
  }
}
CONF

nginx -t -e "$WORK/logs/error.log" -p "$WORK" -c "$WORK/nginx.conf"
nginx -e "$WORK/logs/error.log" -p "$WORK" -c "$WORK/nginx.conf"
sleep 1

base=http://127.0.0.1:18080
curl -s -o /dev/null "$base/business/project_invitation?token=BMSSECRET1"
curl -s -o /dev/null "$base/customers/confirmation?confirmation_token=BMSSECRET2"
curl -s -o /dev/null "$base/customers/password/edit?reset_password_token=BMSSECRET3&locale=ja"
curl -s -o /dev/null "$base/x?a=1&unlock_token=BMSSECRET4"
curl -s -o /dev/null -H "Referer: https://be-my-style.com/business/project_invitation?token=BMSSECRET5" "$base/assets/application.css"
curl -s -o /dev/null "$base/business/project_invitation"
curl -s -o /dev/null "$base/business/timeline?tab=recommended&page=2"
curl -s -o /dev/null "$base/business/projects?mytoken=keep&tokenizer=keep"
sleep 1

log="$WORK/logs/access.log"
echo "----- access.log -----"
cat "$log"
echo "----------------------"

fail=0
check() { if eval "$2"; then echo "OK  $1"; else echo "NG  $1"; fail=1; fi; }
check "秘密の値がどれも残っていない" "! grep -q 'BMSSECRET' '$log'"
check "招待リンクはパスを残してクエリを伏せる" "grep -q '\"GET /business/project_invitation?\[FILTERED\] HTTP/1.1\"' '$log'"
check "確認メール・パスワード再設定・ロック解除も伏せる(要求行の4件)" "[ \$(grep -c '?\[FILTERED\] HTTP' '$log') -eq 4 ]"
check "Referer のトークンも伏せる" "grep -q '\"https://be-my-style.com/business/project_invitation?\[FILTERED\]\"' '$log'"
check "トークンの無い要求はそのまま記録する" "grep -q '\"GET /business/project_invitation HTTP/1.1\"' '$log' && grep -q 'GET /business/timeline?tab=recommended&page=2 HTTP' '$log'"
check "名前の一部に token を含むだけのクエリは伏せない" "grep -q 'GET /business/projects?mytoken=keep&tokenizer=keep HTTP' '$log'"
check "状態コード・User-Agent など既定の項目は残る" "grep -qE '\" 200 [0-9]+ \"' '$log'"

if [ "$fail" -ne 0 ]; then echo "結果: NG あり"; exit 1; fi
echo "結果: すべて OK"
