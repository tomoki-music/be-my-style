# C: 前提条件をすべて満たすときに限り、旧 LINE トークンだけを失効させる。1つでも欠けたら何もしない。
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

# C 失効だけ。前提条件をすべて満たすときに限り、旧 LINE トークンだけを失効させる。1つでも欠けたら何もしない。
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

KEY = "LINE_CHANNEL_ACCESS_TOKEN"

def run(cfg, req=http_req, out=print):
    def rd(p):
        try:
            return open(p).read()
        except OSError:
            return None
    old_t, file_t = rd(cfg["backup_dir"] + "override.conf"), rd(cfg["puma_env"])
    old, s_old = get_one(old_t, KEY) if old_t is not None else (None, "unreadable")
    cur, s_cur = get_one(file_t, KEY) if file_t is not None else (None, "unreadable")
    try:
        rv, s_run = get_one_environ(cfg["environ"](), KEY)
    except Exception:
        rv, s_run = None, "unreadable"
    checks = [("旧トークンを1件に特定", s_old == "ok"),
              ("設定ファイルの現用トークンを1件に特定", s_cur == "ok"),
              ("稼働中Pumaの現用トークンを1件に特定", s_run == "ok")]
    if all(ok for _, ok in checks):
        checks += [("旧 != 設定ファイル", old != cur),
                   ("旧 != 稼働中Puma", old != rv),
                   ("設定ファイル == 稼働中Puma（Puma が現用トークンを読んでいる）", cur == rv)]
    if all(ok for _, ok in checks):
        cur_st = req("https://api.line.me/v2/bot/info", headers={"Authorization": "Bearer " + cur})
        checks.append((f"現用トークンの bot/info が 200（実際 {cur_st}）", cur_st == 200))
    if all(ok for _, ok in checks):
        old_st = req("https://api.line.me/v2/oauth/verify", data={"access_token": old})
        checks.append((f"旧トークンがまだ有効（verify 実際 {old_st}）", old_st == 200))
    for name, ok in checks:
        out(f"[{'OK' if ok else 'NG'}] {name}")
    if not all(ok for _, ok in checks):
        out("RESULT: 失効は実行していません（上の NG を確認。旧トークンが既に失効済みなら NG は最後の1行だけ）")
        return "skipped"
    out(f"revoke old: {req('https://api.line.me/v2/oauth/revoke', data={'access_token': old})} (200=失効)")
    out(f"after: old verify {req('https://api.line.me/v2/oauth/verify', data={'access_token': old})} (400=失効済み) / current bot/info {req('https://api.line.me/v2/bot/info', headers={'Authorization': 'Bearer ' + cur})} (200=疎通OK)")
    return "revoked"

if __name__ == "__main__":
    run({"puma_env": "/etc/be-my-style/puma.env", "backup_dir": "/etc/be-my-style/backup-20261109/", "environ": read_puma_environ})
