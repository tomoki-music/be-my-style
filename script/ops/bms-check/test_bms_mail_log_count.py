import datetime, os, subprocess, sys, tempfile

# ダミーのログだけを使う試験。実行: python3 -I script/ops/bms-check/test_bms_mail_log_count.py
HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "bms-mail-log-count")
ns = {"__name__": "bms_test"}
exec(compile(open(SCRIPT).read(), SCRIPT, "exec"), ns)

NOW = datetime.datetime(2026, 11, 9, 13, 30, 0)
ADDR, MSGID, BODY = "someone@example.com", "<6729abc.1@host.mail>", "ラフ案を共有します"
fails = 0


def check(name, cond):
    global fails
    print(("PASS " if cond else "FAIL ") + name)
    if not cond:
        fails += 1


def ts(minutes_ago):
    t = NOW - datetime.timedelta(minutes=minutes_ago)
    return t.strftime("%Y-%m-%dT%H:%M:%S") + ".123456"


def tag(job):
    return f"[ActiveJob] [ActionMailer::MailDeliveryJob] [{job}]"


def performing(m, job, mailer="CustomerMailer", method="business_follow_mail"):
    return (f"I, [{ts(m)} #4242]  INFO -- : {tag(job)} Performing ActionMailer::MailDeliveryJob (Job ID: {job}) from Async(mailers) "
            f'enqueued at 2026-11-09T13:00:00Z with arguments: "{mailer}", "{method}", "deliver_now", {{:params=>{{:to=>"{ADDR}"}}, :args=>[]}}')


def delivered(m, job):
    return f"I, [{ts(m)} #4242]  INFO -- : {tag(job)} Delivered mail {MSGID} (1234.5ms)"


def performed(m, job):
    return f"I, [{ts(m)} #4242]  INFO -- : {tag(job)} Performed ActionMailer::MailDeliveryJob (Job ID: {job}) from Async(mailers) in 1300.2ms"


def error(m, job, exc="Net::OpenTimeout (execution expired)"):
    return (f"E, [{ts(m)} #4242] ERROR -- : {tag(job)} Error performing ActionMailer::MailDeliveryJob (Job ID: {job}) "
            f"from Async(mailers) in 15000.1ms: {exc}:\n/usr/lib/ruby/net/protocol.rb:1:in `connect' {ADDR}")


OLD = f"I, [{ts(500)} #4242]  INFO -- : [req-1] Started GET \"/\" for 127.0.0.1"
PUMA_BOOT = "[4242] Puma starting in cluster mode...\n[4242] * Listening on unix:///run/puma/puma.sock\n"


def run_case(name, production=None, puma=PUMA_BOOT, prepare=None):
    d = tempfile.mkdtemp() + "/"
    if production is not None:
        open(d + "production.log", "w").write(production)
    if puma is not None:
        open(d + "puma.stdout.log", "w").write(puma)
    if prepare:
        prepare(d)
    lines = []
    status = ns["run"](log_dir=d, now=NOW, out=lines.append)
    out = dict(l.split("=", 1) for l in lines)
    joined = "\n".join(lines)
    check(f"[{name}] output has no address, message id, job id or body",
          not any(s in joined for s in (ADDR, MSGID, "job-", BODY, "Performing", "Net::OpenTimeout (")))
    return status, out


def log(*lines):
    return "\n".join(lines) + "\n"


# 送信成功 1 件
status, out = run_case("success 1", log(OLD, performing(10, "job-a"), delivered(9, "job-a"), performed(9, "job-a")))
check("success: status ok and full coverage", status == "ok" and out["mail_log_status"] == "ok"
      and out["source.production_log"] == "ok coverage=full")
check("success: sent.business_follow_mail=1, failed=0", out["sent.business_follow_mail"] == "1" and out["failed.business_follow_mail"] == "0")
check("success: totals", out["jobs_sent_total"] == "1" and out["jobs_failed_total"] == "0" and out["smtp_error_lines"] == "0")
check("success: puma stdout without Rails lines is reported, not counted", out["source.puma_stdout_log"] == "no_rails_lines coverage=-")

# エラー 1 件（Delivered mail の行が出ていても失敗として数える）
status, out = run_case("error 1", log(OLD, performing(10, "job-b"), delivered(9, "job-b"), error(9, "job-b")))
check("error: failed.business_follow_mail=1, sent=0", out["failed.business_follow_mail"] == "1" and out["sent.business_follow_mail"] == "0")
check("error: jobs_failed_total=1 and smtp_error_lines=1", out["jobs_failed_total"] == "1" and out["smtp_error_lines"] == "1")

# 該当 0 件（ログは読めて期間をカバーしているが、メールが無い）
status, out = run_case("zero", log(OLD, f"I, [{ts(5)} #4242]  INFO -- : [req-2] Completed 200 OK in 12ms"))
check("zero: status ok and counts are 0 (not unknown)", status == "ok" and out["sent.business_follow_mail"] == "0"
      and out["jobs_sent_total"] == "0" and out["failed.thread_post_mail"] == "0")

# 期間外の送信は数えない
status, out = run_case("outside window", log(performing(200, "job-c"), performed(199, "job-c"), OLD.replace(ts(500), ts(600))))
check("outside window: not counted, coverage full", out["jobs_sent_total"] == "0" and out["mail_log_status"] == "ok")

# スレッド投稿通知と、Performing が期間外のジョブ
status, out = run_case("thread post + unknown mailer", log(
    OLD, performing(10, "job-d", "BusinessProjectChatMailer", "thread_post_mail"), performed(9, "job-d"),
    performing(130, "job-e"), performed(110, "job-e"),
    performing(8, "job-f", "CustomerMailer", "create_follow_mail"), performed(7, "job-f")))
check("thread post: sent.thread_post_mail=1", out["sent.thread_post_mail"] == "1")
check("unknown mailer counted only in totals", out["jobs_unknown_mailer"] == "1" and out["jobs_sent_total"] == "3"
      and out["sent.business_follow_mail"] == "0")

# 期間の途中から始まるログ（ローテーション直後など）は partial
status, out = run_case("partial coverage", log(performing(10, "job-g"), performed(9, "job-g")))
check("partial: status partial, counts still shown", status == "partial" and out["mail_log_status"] == "partial"
      and out["sent.business_follow_mail"] == "1")

# ログ取得失敗（判定できない）
for name, kwargs in (
    ("missing files", {"production": None, "puma": None}),
    ("unreadable", {"production": log(OLD, performing(10, "job-h"), performed(9, "job-h")),
                    "prepare": lambda d: os.chmod(d + "production.log", 0)}),
    ("symlink", {"production": None, "prepare": lambda d: os.symlink(d + "../elsewhere.log", d + "production.log")}),
    ("directory", {"production": None, "prepare": lambda d: os.mkdir(d + "production.log")}),
    ("empty", {"production": ""}),
    ("no rails lines", {"production": "garbage\n"}),
):
    status, out = run_case(name, **kwargs)
    check(f"{name}: mail_log_status=unavailable", status == "unavailable" and out["mail_log_status"] == "unavailable")
    check(f"{name}: counts are unknown, not 0", out["sent.business_follow_mail"] == "unknown" and out["jobs_failed_total"] == "unknown")
status, out = run_case("unreadable detail", log(OLD), prepare=lambda d: os.chmod(d + "production.log", 0))
check("unreadable: reported as unreadable", out["source.production_log"] == "unreadable coverage=-")
status, out = run_case("symlink detail", None, prepare=lambda d: (open(d + "target", "w").write(log(OLD)), os.symlink(d + "target", d + "production.log")))
check("symlink to a readable file is not followed", out["source.production_log"] == "not_regular coverage=-")

# 引数は受け付けない（任意のファイルを読ませない）
r = subprocess.run([sys.executable, "-I", SCRIPT, "/etc/passwd"], capture_output=True, text=True)
check("arguments refused", r.returncode == 2 and "arguments_not_accepted" in r.stdout and "root:" not in r.stdout)

print(f"\nTOTAL FAILS: {fails}")
raise SystemExit(1 if fails else 0)
