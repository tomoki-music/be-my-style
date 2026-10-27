#!/usr/bin/env bash
# 本番デプロイ本体。.github/workflows/rails.yml が本番サーバー上で `git reset --hard origin/main` の後に実行する
# (実行中のスクリプトを git reset で書き換えないよう、コード更新とこのスクリプトを分けている)。
#
# 同じコミットでワークフローを再実行しても途中失敗から復旧できるようにするため:
#   - 差分の基準は「デプロイ開始時の HEAD」ではなく「最後に全工程が成功したコミット」(DEPLOY_STATE_DIR に記録)。
#     git reset の後で失敗した場合も、再実行時に同じ差分で必要な処理をやり直す。
#     記録が無い・読めない・差分が取れない場合は、すべて変更ありとして扱う。
#   - db:migrate は毎回実行する(未適用が無ければ何もしない)。
#   - Puma は precompile と migrate が成功した後にだけ再起動し、起動状態と HTTP 応答まで確認する。
#   - 成功の記録は最後(Puma・singing-analyzer の確認後)にだけ書く。
#
# 秘密情報を出力しないこと: set -x・環境変数の一覧・Puma のログ本文は出さない。
set -euo pipefail

: "${DEPLOY_PATH:?DEPLOY_PATH is required}"
PREV_COMMIT="${PREV_COMMIT:-}"
FORCE_ASSETS_CLOBBER="${FORCE_ASSETS_CLOBBER:-false}"
FORCE_FULL_DEPLOY="${FORCE_FULL_DEPLOY:-false}"
DEPLOY_STATE_DIR="${DEPLOY_STATE_DIR:-$HOME/.be-my-style-deploy}"
BUNDLE_BIN="${BUNDLE_BIN:-$HOME/.rbenv/shims/bundle}"
PUMA_SOCKET="${PUMA_SOCKET:-/run/puma/puma.sock}"
PUMA_HEALTHCHECK_PATH="${PUMA_HEALTHCHECK_PATH:-/}"
PUMA_ACTIVE_ATTEMPTS="${PUMA_ACTIVE_ATTEMPTS:-30}"
PUMA_HEALTH_ATTEMPTS="${PUMA_HEALTH_ATTEMPTS:-30}"
RETRY_INTERVAL="${RETRY_INTERVAL:-2}"
PRECOMPILE_POLL_INTERVAL="${PRECOMPILE_POLL_INTERVAL:-30}"

LAST_SUCCESS_FILE="${DEPLOY_STATE_DIR}/last_successful_commit"
ASSETS_COMMIT_FILE="${DEPLOY_STATE_DIR}/assets_precompiled_commit"

CURRENT_STEP="setup"
PUMA_RESTARTED=false
HEALTH_BODY_FILE=""

on_exit() {
  local exit_code=$?
  [ -z "$HEALTH_BODY_FILE" ] || rm -f "$HEALTH_BODY_FILE"
  [ "$exit_code" -ne 0 ] || return 0
  echo "[deploy] ERROR: step '${CURRENT_STEP}' failed (exit=${exit_code})"
  echo "::error::deploy failed at step '${CURRENT_STEP}'. Fix the cause and re-run this workflow; the success record was not updated, so the re-run repeats every required step."
  if [ "$PUMA_RESTARTED" = "true" ]; then
    echo "[deploy] Puma restart was attempted with the new code. Check the site before re-running."
  else
    echo "[deploy] Puma was NOT restarted: the running Puma still serves the previous code (code on disk is already new)."
    echo "[deploy] Re-run before the nightly EC2 stop (JST 02:00): a Puma restart in this state would start the new code on a database that may not be fully migrated."
  fi
}
trap on_exit EXIT

log_step_start() {
  CURRENT_STEP="$1"
  STEP_STARTED_AT=$(date +%s)
  echo "[deploy] $1 start: $(date '+%H:%M:%S')"
}

log_step_finish() {
  echo "[deploy] $1 finished: $(date '+%H:%M:%S') ($(( $(date +%s) - STEP_STARTED_AT ))s)"
}

resource_snapshot() {
  echo "[deploy] memory:"
  free -h || true
  echo "[deploy] disk:"
  df -h || true
  echo "[deploy] swap:"
  swapon --show 2>/dev/null || echo "[deploy] WARNING: No swap detected — OOM risk during assets:precompile"
}

rails_production() {
  RAILS_ENV=production "$BUNDLE_BIN" exec rails "$@"
}

assets_manifests_present() {
  compgen -G "public/assets/.sprockets-manifest-*.json" > /dev/null && [ -f public/packs/manifest.json ]
}

write_state() {
  # 途中で中断しても壊れた記録を残さないよう、一時ファイルから置き換える。
  printf '%s\n' "$2" > "$1.tmp"
  mv "$1.tmp" "$1"
}

DEPLOY_STARTED_AT=$(date +%s)
echo "[deploy] START: $(date '+%H:%M:%S')"
cd "${DEPLOY_PATH}"
mkdir -p "$DEPLOY_STATE_DIR"

echo "[deploy] === resource snapshot ==="
resource_snapshot
echo "[deploy] disk usage (assets/tmp/log):"
du -sh public/assets public/packs tmp log 2>/dev/null || true
echo "[deploy] ========================="

# ---------------------------------------------------------------------------
log_step_start "change detection"
NEW_COMMIT=$(git rev-parse HEAD)
LAST_SUCCESS=$(cat "$LAST_SUCCESS_FILE" 2>/dev/null || true)
echo "[deploy] Commit: ${NEW_COMMIT}"
echo "[deploy] HEAD before git reset: ${PREV_COMMIT:-unknown}"
echo "[deploy] Last successful deploy: ${LAST_SUCCESS:-none}"

FULL_DEPLOY=false
CHANGED_FILES=""

add_changes_since() {
  local base="$1" diff_output
  if ! git cat-file -e "${base}^{commit}" 2>/dev/null; then
    echo "[deploy] Commit ${base} is not available locally; treating everything as changed"
    FULL_DEPLOY=true
    return 0
  fi
  if ! diff_output="$(git diff --name-only "$base" "$NEW_COMMIT")"; then
    echo "[deploy] git diff ${base}..${NEW_COMMIT} failed; treating everything as changed"
    FULL_DEPLOY=true
    return 0
  fi
  CHANGED_FILES="$(printf '%s\n%s\n' "$CHANGED_FILES" "$diff_output")"
}

if [ "$FORCE_FULL_DEPLOY" = "true" ]; then
  echo "[deploy] FORCE_FULL_DEPLOY=true: treating everything as changed"
  FULL_DEPLOY=true
elif [ -z "$LAST_SUCCESS" ]; then
  echo "[deploy] No successful deploy recorded; treating everything as changed"
  FULL_DEPLOY=true
else
  add_changes_since "$LAST_SUCCESS"
fi
# 手動で別のコミットへ切り替えていた場合も拾えるよう、git reset 前の HEAD からの差分も加える。
if [ "$FULL_DEPLOY" = "false" ] && [ -n "$PREV_COMMIT" ] && [ "$PREV_COMMIT" != "$NEW_COMMIT" ]; then
  add_changes_since "$PREV_COMMIT"
fi

CHANGED_FILES="$(printf '%s\n' "$CHANGED_FILES" | sed '/^$/d' | sort -u)"

BUNDLE_DEPS_CHANGED=$FULL_DEPLOY
YARN_DEPS_CHANGED=$FULL_DEPLOY
ASSETS_CHANGED=$FULL_DEPLOY
ANALYZER_CHANGED=$FULL_DEPLOY
ANALYZER_DEPS_CHANGED=$FULL_DEPLOY

while IFS= read -r changed_file; do
  [ -n "$changed_file" ] || continue

  case "$changed_file" in
    Gemfile|Gemfile.lock) BUNDLE_DEPS_CHANGED=true ;;
  esac
  case "$changed_file" in
    package.json|yarn.lock) YARN_DEPS_CHANGED=true ;;
  esac
  case "$changed_file" in
    app/assets/*|app/javascript/*|app/packs/*|config/webpack/*|config/webpacker.yml|config/initializers/assets.rb|package.json|yarn.lock)
      ASSETS_CHANGED=true
      ;;
  esac
  case "$changed_file" in
    singing_analyzer/*) ANALYZER_CHANGED=true ;;
  esac
  case "$changed_file" in
    singing_analyzer/requirements.txt) ANALYZER_DEPS_CHANGED=true ;;
  esac
done <<< "$CHANGED_FILES"

echo "[deploy] Full deploy: ${FULL_DEPLOY}"
echo "[deploy] Changed files since last successful deploy: $(printf '%s\n' "$CHANGED_FILES" | sed '/^$/d' | wc -l | tr -d ' ')"
echo "[deploy] Gemfile changed: ${BUNDLE_DEPS_CHANGED} / yarn deps changed: ${YARN_DEPS_CHANGED} / assets changed: ${ASSETS_CHANGED} / singing-analyzer changed: ${ANALYZER_CHANGED}"
log_step_finish "change detection"

# ---------------------------------------------------------------------------
log_step_start "bundle check/install"
"$BUNDLE_BIN" config set deployment 'true'
"$BUNDLE_BIN" config set without 'development test'
if "$BUNDLE_BIN" check; then
  echo "[deploy] Skip bundle install: bundle check passed"
else
  echo "[deploy] bundle install required (Gemfile changed: ${BUNDLE_DEPS_CHANGED})"
  "$BUNDLE_BIN" install --jobs 4 --retry 3
fi
log_step_finish "bundle check/install"

# ---------------------------------------------------------------------------
log_step_start "yarn check/install"
if [ "$YARN_DEPS_CHANGED" = "true" ] || [ ! -d node_modules ]; then
  echo "[deploy] yarn install required"
  bin/yarn install --frozen-lockfile
else
  echo "[deploy] Skip yarn install: package.json/yarn.lock unchanged since last successful deploy"
fi
log_step_finish "yarn check/install"

# ---------------------------------------------------------------------------
# migrate より前に行う: precompile が失敗しても DB は変更されず、動作中の旧 Puma と DB の組み合わせが変わらない。
log_step_start "assets check/precompile"
ASSETS_COMMIT=$(cat "$ASSETS_COMMIT_FILE" 2>/dev/null || true)
SHOULD_PRECOMPILE_ASSETS=false
if [ "$FORCE_ASSETS_CLOBBER" = "true" ]; then
  SHOULD_PRECOMPILE_ASSETS=true
  echo "[deploy] assets:precompile required: FORCE_ASSETS_CLOBBER=true"
elif [ "$FORCE_FULL_DEPLOY" = "true" ]; then
  SHOULD_PRECOMPILE_ASSETS=true
  echo "[deploy] assets:precompile required: FORCE_FULL_DEPLOY=true"
elif ! assets_manifests_present; then
  SHOULD_PRECOMPILE_ASSETS=true
  echo "[deploy] assets:precompile required: compiled asset manifest is missing"
elif [ "$ASSETS_COMMIT" = "$NEW_COMMIT" ]; then
  echo "[deploy] Skip assets:precompile: already precompiled for ${NEW_COMMIT}"
elif [ -z "$ASSETS_COMMIT" ]; then
  SHOULD_PRECOMPILE_ASSETS=true
  echo "[deploy] assets:precompile required: no record of a successful precompile"
elif [ "$ASSETS_CHANGED" = "true" ]; then
  SHOULD_PRECOMPILE_ASSETS=true
  echo "[deploy] assets:precompile required: asset-related changes since last successful deploy"
else
  echo "[deploy] Skip assets:precompile: no asset-related changes since last successful deploy"
fi

if [ "$SHOULD_PRECOMPILE_ASSETS" = "true" ]; then
  rm -f "$ASSETS_COMMIT_FILE"
  BACKUP_DIR="/tmp/be-my-style-assets-backup-$(date +%Y%m%d%H%M%S)"

  if [ "$FORCE_ASSETS_CLOBBER" = "true" ]; then
    echo "[deploy] FORCE_ASSETS_CLOBBER=true: backing up assets before clobber"
    mkdir -p "$BACKUP_DIR"
    [ -d public/assets ] && cp -a public/assets "$BACKUP_DIR/assets"
    [ -d public/packs ] && cp -a public/packs "$BACKUP_DIR/packs"
    echo "[deploy] assets backup finished: $BACKUP_DIR"
    rails_production assets:clobber
    echo "[deploy] assets:clobber finished: $(date '+%H:%M:%S')"
  fi

  echo "[deploy] --- pre-precompile resource check ---"
  resource_snapshot
  echo "[deploy] -------------------------------------"

  (RAILS_ENV=production NODE_OPTIONS=--max_old_space_size=256 "$BUNDLE_BIN" exec rails assets:precompile) &
  PRECOMPILE_PID=$!
  while kill -0 "$PRECOMPILE_PID" 2>/dev/null; do
    echo "[deploy] assets:precompile still running: $(date '+%H:%M:%S') mem=$(free -h 2>/dev/null | awk '/^Mem:/{print $3"/"$2}') disk=$(df -h / | awk 'NR==2{print $5}')"
    sleep "$PRECOMPILE_POLL_INTERVAL"
  done

  if wait "$PRECOMPILE_PID" && assets_manifests_present; then
    write_state "$ASSETS_COMMIT_FILE" "$NEW_COMMIT"
    echo "[deploy] assets:precompile finished: $(date '+%H:%M:%S')"
    if [ "$FORCE_ASSETS_CLOBBER" = "true" ] && [ -d "$BACKUP_DIR" ]; then
      rm -rf "$BACKUP_DIR"
      echo "[deploy] assets backup deleted"
    fi
  else
    echo "[deploy] ERROR: assets:precompile FAILED (or the compiled manifest is missing). Aborting deploy before db:migrate."
    echo "[deploy] === failure diagnostics ==="
    resource_snapshot
    echo "[deploy] recent OOM events:"
    dmesg --time-format reltime 2>/dev/null | grep -iE "killed process|oom.killer|out of memory" | tail -5 || true
    echo "[deploy] HINT: swap 0 or small → OOM risk. Fix swap: sudo dd if=/dev/zero of=/swapfile bs=1M count=512 && sudo mkswap /swapfile && sudo swapon /swapfile"
    echo "[deploy] HINT: disk free < 500MB → disk full risk. Fix disk: du -sh ~/be-my-style/log/* ~/be-my-style/tmp/cache 2>/dev/null"
    echo "[deploy] =============================="
    if [ "$FORCE_ASSETS_CLOBBER" = "true" ] && [ -d "$BACKUP_DIR" ]; then
      echo "[deploy] Restoring assets from backup: $BACKUP_DIR"
      rm -rf public/assets public/packs
      [ -d "$BACKUP_DIR/assets" ] && cp -a "$BACKUP_DIR/assets" public/assets
      [ -d "$BACKUP_DIR/packs" ] && cp -a "$BACKUP_DIR/packs" public/packs
      echo "[deploy] Assets restored. Existing assets preserved."
    else
      echo "[deploy] Existing assets preserved."
    fi
    false
  fi
fi
log_step_finish "assets check/precompile"

# ---------------------------------------------------------------------------
# 差分に関係なく毎回実行する。未適用が無ければ何もしない。途中で失敗した場合も、再実行で残りを適用する。
# db:abort_if_pending_migrations で、未適用が残っていないことを同じプロセスで確認する。
log_step_start "db:migrate"
rails_production db:migrate db:abort_if_pending_migrations db:version
log_step_finish "db:migrate"

# ---------------------------------------------------------------------------
log_step_start "puma restart"
OLD_PUMA_PID=$(systemctl show puma --property=MainPID --value 2>/dev/null || echo "unknown")
echo "[deploy] Puma MainPID before restart: ${OLD_PUMA_PID}"
PUMA_RESTARTED=true
sudo systemctl restart puma

PUMA_ACTIVE=false
for _ in $(seq 1 "$PUMA_ACTIVE_ATTEMPTS"); do
  if systemctl is-active --quiet puma; then
    PUMA_ACTIVE=true
    break
  fi
  sleep "$RETRY_INTERVAL"
done
if [ "$PUMA_ACTIVE" != "true" ]; then
  echo "[deploy] ERROR: Puma is not active after restart"
  sudo systemctl status puma --no-pager --lines=0 || true
  echo "[deploy] HINT: check 'sudo journalctl -u puma -n 100' and log/puma.stderr.log on the server (not printed here to keep secrets out of CI logs)"
  false
fi
NEW_PUMA_PID=$(systemctl show puma --property=MainPID --value 2>/dev/null || echo "unknown")
echo "[deploy] Puma MainPID after restart: ${NEW_PUMA_PID}"
sudo systemctl status puma --no-pager --lines=0 || true
log_step_finish "puma restart"

# ---------------------------------------------------------------------------
log_step_start "puma health check"
CURL_PUMA=(curl)
# unix ソケットへの接続には書き込み権限が要る。デプロイユーザーに無ければ sudo で確認する。
if [ -S "$PUMA_SOCKET" ] && [ ! -w "$PUMA_SOCKET" ]; then
  CURL_PUMA=(sudo -n curl)
fi
HEALTH_BODY_FILE=$(mktemp)

puma_get() {
  local status
  # Host は config.hosts に含まれる 127.0.0.1 を使う。接続できないと curl は 000 を出して失敗する。
  status=$("${CURL_PUMA[@]}" --silent --max-time 10 --unix-socket "$PUMA_SOCKET" \
    -o "$HEALTH_BODY_FILE" -w '%{http_code}' "http://127.0.0.1$1" 2>/dev/null) || true
  echo "${status:-000}"
}

# ゲスト用トップは 200 とコンパイル済み CSS へのリンクを返す(本番で確認済み)。リダイレクトはエラー画面などを見逃すため成功にしない。
PUMA_HEALTH_OK=false
PUMA_HEALTH_STATUS=""
for attempt in $(seq 1 "$PUMA_HEALTH_ATTEMPTS"); do
  PUMA_HEALTH_STATUS=$(puma_get "$PUMA_HEALTHCHECK_PATH")
  if [ "$PUMA_HEALTH_STATUS" = "200" ]; then
    PUMA_HEALTH_OK=true
    break
  fi
  echo "[deploy] Puma health check attempt ${attempt}/${PUMA_HEALTH_ATTEMPTS}: HTTP ${PUMA_HEALTH_STATUS}"
  sleep "$RETRY_INTERVAL"
done
if [ "$PUMA_HEALTH_OK" != "true" ]; then
  echo "[deploy] ERROR: Puma did not respond successfully to GET ${PUMA_HEALTHCHECK_PATH} (last HTTP ${PUMA_HEALTH_STATUS})"
  false
fi
echo "[deploy] Puma health check: GET ${PUMA_HEALTHCHECK_PATH} → HTTP ${PUMA_HEALTH_STATUS}"

# 新しい Puma が参照している CSS が precompile 済みで、配信できるかを確かめる。
# 本番は config.assets.compile = true のため、ファイルが無くても Puma がその場でコンパイルして 200 を返し得る。
# HTTP だけでなく public/ 配下にファイルがあることも確認する。
STYLESHEET_PATH=$(grep -oE '/assets/application-[0-9a-f]+\.css' "$HEALTH_BODY_FILE" | head -1 || true)
if [ -z "$STYLESHEET_PATH" ]; then
  echo "[deploy] ERROR: no compiled stylesheet link (/assets/application-<digest>.css) in the response to GET ${PUMA_HEALTHCHECK_PATH}"
  false
fi
STYLESHEET_STATUS=$(puma_get "$STYLESHEET_PATH")
if [ "$STYLESHEET_STATUS" != "200" ] || [ ! -s "public${STYLESHEET_PATH}" ]; then
  echo "[deploy] ERROR: stylesheet ${STYLESHEET_PATH}: HTTP ${STYLESHEET_STATUS}, precompiled file present: $([ -s "public${STYLESHEET_PATH}" ] && echo yes || echo no)"
  # 再実行で precompile をやり直すよう、コンパイル済みの記録を消す。
  rm -f "$ASSETS_COMMIT_FILE"
  false
fi
echo "[deploy] Stylesheet check: ${STYLESHEET_PATH} → HTTP 200, precompiled file present"
log_step_finish "puma health check"

# ---------------------------------------------------------------------------
log_step_start "singing-analyzer deploy"
if [ "$ANALYZER_CHANGED" = "true" ]; then
  echo "[deploy] singing-analyzer changes: yes"

  ANALYZER_DIR="${DEPLOY_PATH}/singing_analyzer"
  ANALYZER_VENV_PIP="${ANALYZER_DIR}/.venv/bin/pip"

  if [ "$ANALYZER_DEPS_CHANGED" = "true" ]; then
    "$ANALYZER_VENV_PIP" install -r "${ANALYZER_DIR}/requirements.txt"
    echo "[deploy] singing-analyzer dependency install: performed"
  else
    echo "[deploy] singing-analyzer dependency install: skipped (requirements.txt unchanged)"
  fi

  # singing-analyzer.service is not tracked in this repository (it is
  # managed manually on the production host, see
  # docs/handover/al2023_migration_wiki.md). There is nothing in git
  # to diff against, so daemon-reload is intentionally not automated
  # here. If the unit file is ever brought under version control,
  # this step must be revisited deliberately rather than having
  # daemon-reload silently added.
  echo "[deploy] singing-analyzer daemon-reload: skipped (unit file is not managed by this repository)"

  sudo systemctl restart singing-analyzer
  echo "[deploy] singing-analyzer restart: performed"

  ANALYZER_ACTIVE=false
  for _ in 1 2 3 4 5; do
    if systemctl is-active --quiet singing-analyzer; then
      ANALYZER_ACTIVE=true
      break
    fi
    sleep 1
  done

  if [ "$ANALYZER_ACTIVE" = "true" ]; then
    echo "[deploy] singing-analyzer active check: passed"
  else
    echo "[deploy] ERROR: singing-analyzer active check FAILED"
    sudo systemctl status singing-analyzer --no-pager --lines=20 || true
    false
  fi

  ANALYZER_HEALTH_OK=false
  ANALYZER_HEALTH_LAST_ERROR=""
  for attempt in $(seq 1 15); do
    if ANALYZER_HEALTH_BODY="$(curl --fail --silent --show-error --max-time 5 http://127.0.0.1:8000/health 2>&1)"; then
      if printf '%s' "$ANALYZER_HEALTH_BODY" | grep -q '"status"[[:space:]]*:[[:space:]]*"ok"'; then
        ANALYZER_HEALTH_OK=true
        break
      fi
      ANALYZER_HEALTH_LAST_ERROR="unexpected /health response body"
    else
      ANALYZER_HEALTH_LAST_ERROR="$ANALYZER_HEALTH_BODY"
    fi
    echo "[deploy] singing-analyzer health check attempt ${attempt}/15: not ready yet"
    sleep "$RETRY_INTERVAL"
  done

  if [ "$ANALYZER_HEALTH_OK" = "true" ]; then
    echo "[deploy] singing-analyzer health check: passed"
  else
    echo "[deploy] ERROR: singing-analyzer health check FAILED after 15 attempts (last error: ${ANALYZER_HEALTH_LAST_ERROR})"
    false
  fi
else
  echo "[deploy] singing-analyzer changes: no"
  echo "[deploy] singing-analyzer restart: skipped"
fi
log_step_finish "singing-analyzer deploy"

# ---------------------------------------------------------------------------
CURRENT_STEP="record success"
write_state "$LAST_SUCCESS_FILE" "$NEW_COMMIT"
echo "[deploy] Recorded successful deploy: ${NEW_COMMIT}"
echo "[deploy] END: $(date '+%H:%M:%S') ($(( $(date +%s) - DEPLOY_STARTED_AT ))s)"
echo "Deploy completed successfully."
