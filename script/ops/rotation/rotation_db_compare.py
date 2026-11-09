# D: Puma の設定(/etc/be-my-style/puma.env)とデプロイ用(.env)の DB 設定を比較する（両側1件ずつ・空でないことを確かめてから）。読み取りのみ。
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

# D: Puma の設定(puma.env)とデプロイ用(.env)の DB 設定を、両側1件ずつ・空でないことを確かめてから比較する。
import hashlib

def run(cfg, out=print):
    texts = {}
    for side, path in (("puma_env", cfg["puma_env"]), ("dotenv", cfg["dotenv"])):
        try:
            texts[side] = open(path).read()
        except OSError as e:
            out(f"{side}: unreadable ({type(e).__name__})"); texts[side] = None
    all_ok = True
    for key in ("DB_HOST", "DB_DATABASE", "DB_USERNAME", "DB_PASSWORD"):
        vals, sts = {}, {}
        for side in ("puma_env", "dotenv"):
            if texts[side] is None:
                vals[side], sts[side] = None, "unreadable"
            else:
                vals[side], sts[side] = get_one(texts[side], key)
        if all(sts[s] == "ok" for s in sts):
            same = hashlib.sha256(vals["puma_env"].encode()).digest() == hashlib.sha256(vals["dotenv"].encode()).digest()
            result = "same" if same else "DIFFERENT"
        else:
            result = "NOT_COMPARED"
        if result != "same":
            all_ok = False
        out(f"{key}: puma_env={sts['puma_env']} dotenv={sts['dotenv']} -> {result}")
    if texts["puma_env"] is not None:
        u, st = get_one(texts["puma_env"], "DB_USERNAME")
        out(f"puma_env DB_USERNAME is bms_app: {u == 'bms_app'}")
    out(f"RESULT: {'OK' if all_ok else 'CHECK_NEEDED'}")
    return all_ok

if __name__ == "__main__":
    run({"puma_env": "/etc/be-my-style/puma.env", "dotenv": "/home/ec2-user/be-my-style/.env"})
