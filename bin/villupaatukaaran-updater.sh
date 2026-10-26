#!/usr/bin/env bash
# villupaatukaaran-updater.sh
# Spawned as a detached process by the Dart app during self-update.
# Waits for the app to exit, replaces the bundle, then relaunches.
#
# Usage:
#   bash villupaatukaaran-updater.sh <APP_PID> <NEW_BUNDLE_DIR> <INSTALL_DIR> <RELAUNCH_BIN>
#
# Arguments:
#   APP_PID      – PID of the running app process to wait for
#   NEW_BUNDLE_DIR – path to the extracted new bundle root directory
#   INSTALL_DIR  – path to the current installed bundle directory (contains the old binary)
#   RELAUNCH_BIN – absolute path to the binary to launch after update

set -euo pipefail

APP_PID="${1:-}"
NEW_BUNDLE="${2:-}"
INSTALL_DIR="${3:-}"
RELAUNCH_BIN="${4:-}"

LOG_FILE="${INSTALL_DIR}/villupaatukaaran-update.log"

log() {
  echo "[$(date -Iseconds)] $*" | tee -a "$LOG_FILE"
}

log "=== Villupaatukaaran Updater Starting ==="
log "APP_PID    : $APP_PID"
log "NEW_BUNDLE : $NEW_BUNDLE"
log "INSTALL_DIR: $INSTALL_DIR"
log "RELAUNCH   : $RELAUNCH_BIN"

# ─── Validate arguments ───────────────────────────────────────────────────────
if [[ -z "$APP_PID" || -z "$NEW_BUNDLE" || -z "$INSTALL_DIR" || -z "$RELAUNCH_BIN" ]]; then
  log "ERROR: Missing required arguments. Aborting."
  exit 1
fi

if [[ ! -d "$NEW_BUNDLE" ]]; then
  log "ERROR: New bundle directory '$NEW_BUNDLE' does not exist. Aborting."
  exit 1
fi

if [[ ! -d "$INSTALL_DIR" ]]; then
  log "ERROR: Install directory '$INSTALL_DIR' does not exist. Aborting."
  exit 1
fi

# ─── Check write permissions ──────────────────────────────────────────────────
if [[ ! -w "$INSTALL_DIR" ]]; then
  log "ERROR: No write permission to '$INSTALL_DIR'. Aborting."
  exit 2
fi

# ─── Wait for the app process to exit ────────────────────────────────────────
log "Waiting for app process $APP_PID to exit…"
WAITED=0
MAX_WAIT=30  # seconds

while kill -0 "$APP_PID" 2>/dev/null; do
  sleep 0.5
  WAITED=$((WAITED + 1))
  if [[ $WAITED -ge $((MAX_WAIT * 2)) ]]; then
    log "WARNING: App did not exit after ${MAX_WAIT}s. Proceeding anyway."
    break
  fi
done

log "App process has exited (or timed out). Proceeding with update."
sleep 0.5  # brief extra grace period

# ─── Replace bundle files ─────────────────────────────────────────────────────
log "Replacing bundle files…"

if command -v rsync &>/dev/null; then
  log "Using rsync for atomic replacement."
  rsync -a --delete "${NEW_BUNDLE}/" "${INSTALL_DIR}/"
else
  log "rsync not found — using cp -a fallback."
  # Remove old files that won't be overwritten
  rm -rf "${INSTALL_DIR:?}/data" "${INSTALL_DIR:?}/lib"
  cp -a "${NEW_BUNDLE}/." "${INSTALL_DIR}/"
fi

# Make the binary executable (in case tar didn't preserve it)
if [[ -f "$RELAUNCH_BIN" ]]; then
  chmod +x "$RELAUNCH_BIN"
fi

log "Bundle replacement complete."

# ─── Clean up temp extraction directory ──────────────────────────────────────
log "Cleaning up temp files…"
PARENT_DIR="$(dirname "$NEW_BUNDLE")"
rm -rf "$NEW_BUNDLE"

# Also clean up the downloaded archive if present
find "$PARENT_DIR" -maxdepth 1 \
  \( -name "*.tar.gz" -o -name "*.tar.gz.sha256" \) \
  -delete 2>/dev/null || true

log "Cleanup complete."

# ─── Re-launch updated application ───────────────────────────────────────────
if [[ -x "$RELAUNCH_BIN" ]]; then
  log "Launching updated app: $RELAUNCH_BIN"
  # Launch as a new independent process, detached from this script
  nohup "$RELAUNCH_BIN" > /dev/null 2>&1 &
  disown
  log "App relaunched (PID: $!)."
else
  log "ERROR: Binary '$RELAUNCH_BIN' is not executable. Manual restart required."
fi

log "=== Updater finished ==="
exit 0

