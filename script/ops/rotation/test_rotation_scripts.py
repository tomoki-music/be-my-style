import os, tempfile

# ダミー値だけを使う試験。実行: python3 -I script/ops/rotation/test_rotation_scripts.py
HERE = os.path.dirname(os.path.abspath(__file__))

def load(name):
    src = open(os.path.join(HERE, name)).read()
    ns = {"__name__": "bms_test"}
    exec(compile(src, name, "exec"), ns)
    return ns

def write(d, name, text):
    p = os.path.join(d, name)
    with open(p, "w", newline="") as f:
        f.write(text)
    return p

K = "LINE_CHANNEL_ACCESS_TOKEN"
OLD, NEW = "DUMMYOLDtokenAAA111", "DUMMYNEWtokenBBB222"
fails = 0

def check(name, cond):
    global fails
    print(("PASS " if cond else "FAIL ") + name)
    if not cond:
        fails += 1

# ---------- revoke ----------
rv = load("rotation_line_revoke.py")

def stub(cur_status=200, old_status=200):
    calls = []
    def req(url, data=None, headers=None):
        tok = (data or {}).get("access_token") or (headers or {}).get("Authorization", "").replace("Bearer ", "")
        calls.append((url.rsplit("/", 1)[-1], tok))
        if url.endswith("/bot/info"):
            return cur_status if tok == NEW else 401
        if url.endswith("/verify"):
            return old_status if tok == OLD else 200
        if url.endswith("/revoke"):
            return 200
        return 0
    return req, calls

def scenario(name, backup, file_text, running, expect, cur_status=200, old_status=200):
    d = tempfile.mkdtemp()
    write(d, "override.conf", backup)
    pe = write(d, "puma_env.txt", file_text)
    env_bytes = ("PATH=/usr/bin\0" + (f"{K}={running}\0" if running is not None else "")).encode()
    req, calls = stub(cur_status, old_status)
    lines = []
    res = rv["run"]({"puma_env": pe, "backup_dir": d + "/", "environ": lambda: env_bytes}, req=req, out=lines.append)
    revoked = [t for u, t in calls if u == "revoke"]
    check(f"revoke[{name}] result={res} expected={expect}", res == expect)
    check(f"revoke[{name}] never revokes current token", NEW not in revoked)
    check(f"revoke[{name}] revokes only old when revoked", revoked == ([OLD] if expect == "revoked" else []))
    joined = "\n".join(lines)
    check(f"revoke[{name}] output has no token values", OLD not in joined and NEW not in joined)

std_backup = f'[Service]\nEnvironment="LINE_CHANNEL_SECRET=dummysecret"\nEnvironment="{K}={OLD}"\n'
scenario("normal quoted backup", std_backup, f"{K}={NEW}\n", NEW, "revoked")
scenario("unquoted backup line", f"Environment={K}={OLD}\n", f"{K}={NEW}\n", NEW, "revoked")
scenario("file value quoted", std_backup, f'{K}="{NEW}"\n', NEW, "revoked")
scenario("file export + CRLF", std_backup, f"export {K}={NEW}\r\n", NEW, "revoked")
scenario("old equals current", f'Environment="{K}={NEW}"\n', f"{K}={NEW}\n", NEW, "skipped")
scenario("old missing in backup", '[Service]\nEnvironment="LINE_CHANNEL_SECRET=x"\n', f"{K}={NEW}\n", NEW, "skipped")
scenario("duplicate key in file", std_backup, f"{K}={NEW}\n{K}={OLD}\n", NEW, "skipped")
scenario("empty value in file", std_backup, f"{K}=\n", NEW, "skipped")
scenario("missing key in file", std_backup, "OTHER=1\n", NEW, "skipped")
scenario("puma still running old token", std_backup, f"{K}={NEW}\n", OLD, "skipped")
scenario("puma env lacks token", std_backup, f"{K}={NEW}\n", None, "skipped")
scenario("two assignments on one backup line", f'Environment="LINE_CHANNEL_SECRET=x" "{K}={OLD}"\n', f"{K}={NEW}\n", NEW, "skipped")
scenario("unbalanced quote in file", std_backup, f'{K}="{NEW}\n', NEW, "skipped")
scenario("current token fails bot/info", std_backup, f"{K}={NEW}\n", NEW, "skipped", cur_status=401)
scenario("old already revoked", std_backup, f"{K}={NEW}\n", NEW, "skipped", old_status=400)
d = tempfile.mkdtemp()
req, calls = stub()
res = rv["run"]({"puma_env": d + "/nope", "backup_dir": d + "/", "environ": lambda: b""}, req=req, out=lambda s: None)
check("revoke[files unreadable] skipped and no API calls", res == "skipped" and calls == [])

# ---------- old check (read-only) ----------
oc = load("rotation_old_check.py")
d = tempfile.mkdtemp()
write(d, "override.conf", std_backup)
write(d, "openai.conf", '[Service]\nEnvironment="OPENAI_API_KEY=DUMMYOLDopenai"\n')
pe = write(d, "puma_env.txt", f"{K}={NEW}\nOPENAI_API_KEY=DUMMYNEWopenai\n")
req, calls = stub()
lines = []
oc["run"]({"puma_env": pe, "backup_dir": d + "/", "environ": lambda: f"{K}={NEW}\0OPENAI_API_KEY=DUMMYNEWopenai\0".encode()}, req=req, out=lines.append)
check("check[read-only] never calls revoke", all(u != "revoke" for u, _ in calls))
check("check[read-only] output has no values", not any(v in "\n".join(lines) for v in (OLD, NEW, "DUMMYOLDopenai", "DUMMYNEWopenai")))
print("    sample output:", " | ".join(lines))

# ---------- DB compare ----------
db = load("rotation_db_compare.py")
base = "DB_HOST=h.example\nDB_DATABASE=be_my_style\nDB_USERNAME=bms_app\nDB_PASSWORD=DUMMYpw123\n"
def dbcase(name, puma_text, dot_text, expect_ok, expect_line=None):
    d = tempfile.mkdtemp()
    pe, de = write(d, "puma_env.txt", puma_text), write(d, "dotenv.txt", dot_text)
    lines = []
    ok = db["run"]({"puma_env": pe, "dotenv": de}, out=lines.append)
    check(f"db[{name}] ok={ok} expected={expect_ok}", ok == expect_ok)
    if expect_line:
        check(f"db[{name}] reports '{expect_line}'", any(expect_line in l for l in lines))
    check(f"db[{name}] output has no values", "DUMMYpw123" not in "\n".join(lines) and "h.example" not in "\n".join(lines))
dbcase("identical", base, base, True)
dbcase("quoted/export on dotenv side", base, 'export DB_HOST="h.example"\nDB_DATABASE=be_my_style\nDB_USERNAME=\'bms_app\'\nDB_PASSWORD=DUMMYpw123\r\n', True)
dbcase("password differs", base, base.replace("DUMMYpw123", "DUMMYother"), False, "DB_PASSWORD: puma_env=ok dotenv=ok -> DIFFERENT")
dbcase("key missing on dotenv", base, base.replace("DB_PASSWORD=DUMMYpw123\n", ""), False, "dotenv=count=0 -> NOT_COMPARED")
dbcase("duplicate on puma side", base + "DB_PASSWORD=DUMMYpw123\n", base, False, "puma_env=count=2 dotenv=ok -> NOT_COMPARED")
dbcase("empty on both sides", base.replace("DUMMYpw123", ""), base.replace("DUMMYpw123", ""), False, "puma_env=empty dotenv=empty -> NOT_COMPARED")
d = tempfile.mkdtemp()
lines = []
ok = db["run"]({"puma_env": d + "/missing", "dotenv": write(d, "dotenv.txt", base)}, out=lines.append)
check("db[puma_env unreadable] not ok", ok is False and any("NOT_COMPARED" in l for l in lines))

# ---------- old LINE classify (read-only) ----------
cl = load("rotation_line_old_classify.py")
def body(desc):
    return ('{"error":"invalid_request","error_description":"%s"}' % desc).encode()

def cl_stub(old_verify=400, old_body=body("access_token invalid"), old_bot=401, cur_verify=200, cur_bot=200):
    calls = []
    def req(url, data=None, headers=None):
        tok = (data or {}).get("access_token") or (headers or {}).get("Authorization", "").replace("Bearer ", "")
        calls.append((url.rsplit("/", 1)[-1], tok))
        if url.endswith("/revoke"):
            return 200, b""
        if tok == NEW:
            return (cur_verify, b'{"client_id":"1","expires_in":1,"scope":"P CM"}') if url.endswith("/verify") else (cur_bot, b"{}")
        return (old_verify, old_body) if url.endswith("/verify") else (old_bot, b"{}")
    return req, calls

def clcase(name, expect, backup=std_backup, file_text=f"{K}={NEW}\n", extra_files=None, **kw):
    d = tempfile.mkdtemp()
    write(d, "override.conf", backup)
    for n, t in (extra_files or {}).items():
        write(d, n, t)
    pe = write(d, "puma_env.txt", file_text)
    req, calls = cl_stub(**kw)
    lines = []
    res = cl["run"]({"puma_env": pe, "backup_dir": d + "/"}, req=req, out=lines.append)
    joined = "\n".join(lines)
    check(f"classify[{name}] result={res} expected={expect}", res == expect)
    check(f"classify[{name}] never calls revoke", all(u != "revoke" for u, _ in calls))
    check(f"classify[{name}] output has no token values or body",
          OLD not in joined and NEW not in joined and "access_token" not in joined and "token expired" not in joined and "{" not in joined)
    return lines, calls

lines, _ = clcase("invalid (official description)", "invalid")
print("    sample output:", " | ".join(lines))
clcase("invalid with different case/space", "invalid", old_body=body("Access_Token  Invalid"))
clcase("expired (v2.1 style description)", "expired", old_body=body("The access token expired"))
lines, _ = clcase("malformed", "malformed", old_body=body("access_token in invalid format"))
check("classify[malformed] reports extraction lines", any(l.startswith("extract: override.conf") for l in lines))
clcase("unknown description", "unknown", old_body=body("something else"))
clcase("unknown error field", "unknown", old_body=b'{"error":"invalid_client","error_description":"access_token invalid"}')
clcase("unparsable body", "unknown", old_body=b"<html>")
clcase("500 from LINE", "unknown", old_verify=500, old_body=b"")
clcase("network error", "unknown", old_verify="ERR:URLError", old_body=b"")
clcase("invalid but bot/info not 401", "unknown", old_bot=500)
clcase("still valid", "valid", old_verify=200, old_body=b'{"expires_in":1}', old_bot=200)
clcase("verify 400 but bot/info 200", "valid", old_bot=200)
clcase("current verify fails", "unknown", cur_verify=400)
_, calls = clcase("old equals current", "unknown", backup=f'Environment="{K}={NEW}"\n')
check("classify[old equals current] makes no API calls", calls == [])
_, calls = clcase("old missing", "unknown", backup='[Service]\nEnvironment="LINE_CHANNEL_SECRET=x"\n')
check("classify[old missing] makes no API calls", calls == [])
lines, _ = clcase("extraction styles", "invalid", backup=f'Environment="LINE_CHANNEL_SECRET=x" "{K}=dup"\r\nEnvironment="{K}={OLD}"\n',
                  extra_files={"env.conf": f"{K}=DUMMYthird\n"})
check("classify[extraction styles] counts lines", any("override.conf lines_with_key=2" in l and "multiple_assignments" in l and "has_cr=True" in l for l in lines))
check("classify[extraction styles] reports other backup files", any(l.startswith("extract: env.conf lines_with_key=1") for l in lines))
check("classify[extraction styles] no dummy values", "DUMMYthird" not in "\n".join(lines))

print(f"\nTOTAL FAILS: {fails}")
raise SystemExit(1 if fails else 0)
