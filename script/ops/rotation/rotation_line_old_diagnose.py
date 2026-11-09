# C': 旧 LINE トークンの verify が 400 だったとき、それが「トークン自体が無効（失効・期限切れ）」によるものかを判定する。読み取りのみ（失効はしない）。
# 実行は本番サーバー上で、利用者（管理者）が行う。秘密値・応答本文は出力しない（状態コード・固定の分類名・一致の真偽のみ）。
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

# 判定方法: 現用・その場で作った実在しないトークン・旧の 3 本を、同じ関数で同じ形の要求にする。
# 現用が 200 なら要求の形は正しい。旧が実在しないトークンと同じ 400 応答（error 種別と説明文の一致を真偽だけで比較）で、
# かつ bot/info が 401 なら、旧トークンは API に使えない（無効または期限切れ）と判定できる。
import urllib.request, urllib.parse, urllib.error, json, hashlib, secrets, string

KEY = "LINE_CHANNEL_ACCESS_TOKEN"
KNOWN_ERRORS = ("invalid_request", "invalid_client", "invalid_grant", "unauthorized_client")

def http_req(url, data=None, headers=None):
    """(status, body bytes)。本文は分類にだけ使い、出力しない。"""
    r = urllib.request.Request(url, data=urllib.parse.urlencode(data).encode() if data else None, headers=headers or {})
    try:
        with urllib.request.urlopen(r, timeout=15) as res:
            return res.status, res.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()
    except Exception as e:
        return "ERR:" + type(e).__name__, b""

def probe(token, req):
    vs, vb = req("https://api.line.me/v2/oauth/verify", data={"access_token": token})
    try:
        j = json.loads(vb or b"{}")
    except Exception:
        j = None
    if not isinstance(j, dict):
        err, desc = "unparsable", ""
    else:
        e = j.get("error")
        err = e if e in KNOWN_ERRORS else ("none" if e is None else "other")
        desc = str(j.get("error_description", ""))
    bs, _ = req("https://api.line.me/v2/bot/info", headers={"Authorization": "Bearer " + token})
    return {"verify": vs, "error": err, "desc_digest": hashlib.sha256(desc.encode()).hexdigest(), "bot_info": bs}

def random_token(n):
    alphabet = string.ascii_letters + string.digits + "+/"
    return "".join(secrets.choice(alphabet) for _ in range(max(n, 20)))

def run(cfg, req=http_req, out=print):
    def rd(p):
        try:
            return open(p).read()
        except OSError:
            return None
    old_t, file_t = rd(cfg["backup_dir"] + "override.conf"), rd(cfg["puma_env"])
    old, s_old = get_one(old_t, KEY) if old_t is not None else (None, "unreadable")
    cur, s_cur = get_one(file_t, KEY) if file_t is not None else (None, "unreadable")
    out(f"parse: old={s_old} file={s_cur}")
    if s_old != "ok" or s_cur != "ok":
        out("RESULT: INCONCLUSIVE (旧・現用のトークンを1件ずつ特定できない。API は呼んでいません)")
        return "inconclusive"
    if old == cur:
        out("RESULT: INCONCLUSIVE (旧と現用が同じ値。API は呼んでいません)")
        return "inconclusive"
    dummy = random_token(len(old))
    while dummy in (old, cur):
        dummy = random_token(len(old))
    p_cur, p_dummy, p_old = probe(cur, req), probe(dummy, req), probe(old, req)
    for name, p in (("current", p_cur), ("random", p_dummy), ("old", p_old)):
        out(f"{name}: verify={p['verify']} error={p['error']} bot/info={p['bot_info']}")
    same = (p_old["verify"] == p_dummy["verify"] and p_old["error"] == p_dummy["error"]
            and p_old["desc_digest"] == p_dummy["desc_digest"])
    out(f"old response same as random token (status+error+description): {same}")
    if p_old["verify"] == 200 or p_old["bot_info"] == 200:
        out("RESULT: OLD_STILL_VALID (旧トークンはまだ使える。rotation_line_revoke.py で失効させる)")
        return "still_valid"
    checks = [("現用の verify が 200（要求の形が正しい）", p_cur["verify"] == 200),
              ("現用の bot/info が 200", p_cur["bot_info"] == 200),
              ("実在しないトークンの verify が 400", p_dummy["verify"] == 400),
              ("旧の verify が 400", p_old["verify"] == 400),
              ("旧の応答が実在しないトークンと同じ", same),
              ("旧の bot/info が 401（API に使えない）", p_old["bot_info"] == 401)]
    for name, ok in checks:
        out(f"[{'OK' if ok else 'NG'}] {name}")
    if all(ok for _, ok in checks):
        out("RESULT: OLD_UNUSABLE (旧トークンは無効または期限切れ。失効操作は不要)")
        return "unusable"
    out("RESULT: INCONCLUSIVE (NG の行を確認。判定できないため削除には進まない)")
    return "inconclusive"

if __name__ == "__main__":
    run({"puma_env": "/etc/be-my-style/puma.env", "backup_dir": "/etc/be-my-style/backup-20261109/"})
