# A・C: 旧 OpenAI キー・旧 LINE トークンの有効性と、現用の値との一致を確認する。読み取りのみ（失効はしない）。
# 実行は本番サーバー上で、利用者（管理者）が行う。秘密値は出力しない（有無・一致・状態コードのみ）。
# 手順: docs/handover/production_access.md の「認証情報ローテーション後の確認」。
# 実行前に、root 所有の一時ディレクトリへコピーし、レビュー済みの SHA-256 と照合してから、そのコピーを実行する。

# 共通: 設定ファイルから「指定キーがちょうど1件・空でない」値だけを取り出す。値は出力しない。
import re

def parse_entries(text):
    out = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or line.startswith("["):
            continue
        if line.startswith("Environment="):
            line = line[len("Environment="):].strip()
            if len(line) >= 2 and line[0] == line[-1] and line[0] in "\"'":
                line = line[1:-1]
        if line.startswith("export "):
            line = line[len("export "):].lstrip()
        if "=" not in line:
            continue
        k, v = line.split("=", 1)
        k, v = k.strip(), v.strip()
        if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
            v = v[1:-1]
        out.append((k, v))
    return out

def get_one(text, key):
    """(value or None, status)。status は ok / count=N / empty / unexpected_chars"""
    vals = [v for k, v in parse_entries(text) if k == key]
    if len(vals) != 1:
        return None, f"count={len(vals)}"
    v = vals[0]
    if not v:
        return None, "empty"
    if re.search(r"[\s\"'\\]", v):
        return None, "unexpected_chars"
    return v, "ok"

def get_one_environ(raw_bytes, key):
    text = "\n".join(raw_bytes.decode(errors="replace").split("\0"))
    vals = [l.split("=", 1)[1] for l in text.splitlines() if l.startswith(key + "=")]
    if len(vals) != 1:
        return None, f"count={len(vals)}"
    return (vals[0], "ok") if vals[0] else (None, "empty")

# A・C 確認だけ（失効はしない）。旧値・設定ファイル・稼働中 Puma の値を取り出し、一致と有効性を状態コードで出す。
import urllib.request, urllib.parse, urllib.error, subprocess

def http_req(url, data=None, headers=None):
    r = urllib.request.Request(url, data=urllib.parse.urlencode(data).encode() if data else None, headers=headers or {})
    try:
        with urllib.request.urlopen(r, timeout=15) as res:
            return res.status
    except urllib.error.HTTPError as e:
        return e.code
    except Exception as e:
        return "ERR:" + type(e).__name__

def read_puma_environ():
    pid = subprocess.run(["systemctl", "show", "puma", "-p", "MainPID", "--value"], capture_output=True, text=True).stdout.strip()
    return open(f"/proc/{pid}/environ", "rb").read()

def load(cfg, key, backup_file):
    def rd(p):
        try:
            return open(p).read()
        except OSError:
            return None
    old_t, file_t = rd(backup_file), rd(cfg["puma_env"])
    old, s_old = get_one(old_t, key) if old_t is not None else (None, "unreadable")
    cur, s_cur = get_one(file_t, key) if file_t is not None else (None, "unreadable")
    try:
        run_v, s_run = get_one_environ(cfg["environ"](), key)
    except Exception as e:
        run_v, s_run = None, "unreadable"
    return old, s_old, cur, s_cur, run_v, s_run

def run(cfg, req=http_req, out=print):
    # LINE
    old, s_old, cur, s_cur, rv, s_run = load(cfg, "LINE_CHANNEL_ACCESS_TOKEN", cfg["backup_dir"] + "override.conf")
    out(f"line parse: old={s_old} file={s_cur} running={s_run}")
    if s_cur == "ok":
        out(f"line current(file) bot/info: {req('https://api.line.me/v2/bot/info', headers={'Authorization': 'Bearer ' + cur})} (200=疎通OK)")
    if s_cur == "ok" and s_run == "ok":
        out(f"line file==running: {cur == rv}")
    if s_old == "ok":
        out(f"line old==file: {old == cur if s_cur == 'ok' else 'unknown'} / old==running: {old == rv if s_run == 'ok' else 'unknown'}")
        out(f"line old verify: {req('https://api.line.me/v2/oauth/verify', data={'access_token': old})} (200=まだ有効 / 400=失効済み)")
    else:
        out("line old verify: NOT_CHECKED (旧トークンを1件に特定できない)")
    # OpenAI
    old, s_old, cur, s_cur, rv, s_run = load(cfg, "OPENAI_API_KEY", cfg["backup_dir"] + "openai.conf")
    out(f"openai parse: old={s_old} file={s_cur} running={s_run}")
    if s_old == "ok":
        out(f"openai old==file: {old == cur if s_cur == 'ok' else 'unknown'} / old==running: {old == rv if s_run == 'ok' else 'unknown'}")
        out(f"openai old /v1/models: {req('https://api.openai.com/v1/models', headers={'Authorization': 'Bearer ' + old})} (200=まだ有効 / 401=失効済み)")
    else:
        out("openai old /v1/models: NOT_CHECKED (旧キーを1件に特定できない)")

if __name__ == "__main__":
    run({"puma_env": "/etc/be-my-style/puma.env", "backup_dir": "/etc/be-my-style/backup-20261109/", "environ": read_puma_environ})
