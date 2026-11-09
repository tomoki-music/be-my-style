# C': 旧 LINE トークンの verify 応答を、LINE 公式リファレンスの記載に沿って「無効」「期限切れ」「形式不正」「不明」に分類する。読み取りのみ（失効はしない）。
# 実行は本番サーバー上で、利用者（管理者）が行う。秘密値・応答本文は出力しない（分類名・状態コード・取り出し方の特徴のみ）。
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

# 分類の根拠（LINE Messaging API リファレンス「短期・長期のチャネルアクセストークンの有効性を検証する」POST /v2/oauth/verify）:
#   200 = 有効。400 は error=invalid_request で、error_description が
#   "access_token invalid"（無効）/ "access_token in invalid format"（形式不正）。期限切れは v2.1 の verify が
#   "The access token expired" と返すため、説明文に "expired" を含むものを期限切れとする。それ以外はすべて不明。
import os, json, urllib.request, urllib.parse, urllib.error

KEY = "LINE_CHANNEL_ACCESS_TOKEN"
DESCRIPTIONS = {
    "access_token invalid": "invalid",
    "access_token in invalid format": "malformed",
}
LABELS = {"invalid": "無効", "expired": "期限切れ", "malformed": "形式不正", "unknown": "不明", "valid": "有効"}

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

def classify(status, body):
    if status == 200:
        return "valid"
    if status != 400:
        return "unknown"
    try:
        j = json.loads(body or b"")
    except Exception:
        return "unknown"
    if not isinstance(j, dict) or j.get("error") != "invalid_request":
        return "unknown"
    desc = " ".join(str(j.get("error_description", "")).split()).lower()
    if desc in DESCRIPTIONS:
        return DESCRIPTIONS[desc]
    if "expired" in desc:
        return "expired"
    return "unknown"

TOKEN_SHAPE = re.compile(r"^[A-Za-z0-9+/]+={0,2}$")
ASSIGN = re.compile(r"(?:^|[\s\"'])[A-Za-z_][A-Za-z0-9_]*=")

def line_style(raw):
    line = raw.strip()
    body = line[len("Environment="):].strip() if line.startswith("Environment=") else line
    if len(ASSIGN.findall(body)) > 1:
        return "multiple_assignments"
    if line.startswith("Environment="):
        return "environment_quoted" if body[:1] in "\"'" else "environment_unquoted"
    if line.startswith("export "):
        return "export"
    return "plain"

def extraction_report(cfg, old, cur, out):
    """退避ファイルからの取り出し方を、値を出さずに特徴だけで示す。"""
    names = []
    try:
        names = sorted(n for n in os.listdir(cfg["backup_dir"]) if os.path.isfile(cfg["backup_dir"] + n))
    except OSError:
        out("extract: backup_dir unreadable")
    for n in names:
        try:
            t = open(cfg["backup_dir"] + n, newline="").read()
        except OSError:
            out(f"extract: {n} unreadable"); continue
        hits = [l for l in t.split("\n") if re.search(r"(?:^|[\s\"'=])" + KEY + "=", l) and not l.strip().startswith("#")]
        if hits:
            styles = ",".join(sorted({line_style(l) for l in hits}))
            out(f"extract: {n} lines_with_key={len(hits)} style={styles} has_cr={any(l.endswith(chr(13)) for l in hits)}")
    if old is not None:
        out(f"extract: old length={len(old)} token_shape_ok={bool(TOKEN_SHAPE.match(old))} "
            f"same_length_as_current={cur is not None and len(old) == len(cur)} "
            f"starts_with_bearer={old.lower().startswith('bearer')} has_percent={'%' in old}")
    if cur is not None:
        out(f"extract: current length={len(cur)} token_shape_ok={bool(TOKEN_SHAPE.match(cur))}")

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
    extraction_report(cfg, old, cur, out)
    if s_old != "ok" or s_cur != "ok" or old == cur:
        reason = "旧と現用が同じ値" if (s_old == s_cur == "ok") else "旧・現用のトークンを1件ずつ特定できない"
        out(f"RESULT: OLD_UNKNOWN 不明 ({reason}。API は呼んでいません)")
        return "unknown"
    cs, cb = req("https://api.line.me/v2/oauth/verify", data={"access_token": cur})
    cbs, _ = req("https://api.line.me/v2/bot/info", headers={"Authorization": "Bearer " + cur})
    os_, ob = req("https://api.line.me/v2/oauth/verify", data={"access_token": old})
    obs, _ = req("https://api.line.me/v2/bot/info", headers={"Authorization": "Bearer " + old})
    c_cls, o_cls = classify(cs, cb), classify(os_, ob)
    out(f"current: verify={cs} class={c_cls} bot/info={cbs}")
    out(f"old: verify={os_} class={o_cls} bot/info={obs}")
    if c_cls != "valid" or cbs != 200:
        out("RESULT: OLD_UNKNOWN 不明 (現用の確認が 200 でないため、要求の形を確かめられない)")
        return "unknown"
    if o_cls == "valid" or obs == 200:
        out("RESULT: OLD_STILL_VALID 有効 (旧トークンはまだ使える。rotation_line_revoke.py で失効させる)")
        return "valid"
    if o_cls in ("invalid", "expired") and obs == 401:
        out(f"RESULT: OLD_{o_cls.upper()} {LABELS[o_cls]} (旧トークンは使えない。失効操作は不要)")
        return o_cls
    if o_cls == "malformed":
        out("RESULT: OLD_MALFORMED 形式不正 (取り出し方を先に確認する。上の extract 行を共有。削除には進まない)")
        return "malformed"
    out(f"RESULT: OLD_UNKNOWN 不明 (class={o_cls} bot/info={obs}。削除には進まない)")
    return "unknown"

if __name__ == "__main__":
    run({"puma_env": "/etc/be-my-style/puma.env", "backup_dir": "/etc/be-my-style/backup-20261109/"})
