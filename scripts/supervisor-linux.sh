#!/usr/bin/env bash
# Linux supervisor — setsid/nohup fallback with auto-respawn.
# Sourced by daemon.sh; expects CTI_HOME, SKILL_DIR, PID_FILE, STATUS_FILE, LOG_FILE.

# ── Public interface (called by daemon.sh) ──

supervisor_start() {
  local sentinel="$CTI_HOME/runtime/stop-sentinel"
  rm -f "$sentinel"

  # Write a self-contained respawn wrapper script
  local wrapper
  wrapper=$(mktemp /tmp/cti-respawn-XXXXXX.sh)
  cat > "$wrapper" <<WRAPPER
#!/usr/bin/env bash
sentinel="$sentinel"
daemon="$SKILL_DIR/dist/daemon.mjs"
logfile="$LOG_FILE"
while true; do
  if [ -f "\$sentinel" ]; then
    rm -f "\$sentinel"
    break
  fi
  node "\$daemon" >> "\$logfile" 2>&1
  rc=\$?
  if [ -f "\$sentinel" ]; then
    rm -f "\$sentinel"
    break
  fi
  echo "[\$(date -u +%Y-%m-%dT%H:%M:%SZ)] [supervisor] Daemon exited (rc=\$rc), restarting in 3s..." >> "\$logfile"
  sleep 3
done
rm -f "$wrapper"
WRAPPER
  chmod +x "$wrapper"

  if command -v setsid >/dev/null 2>&1; then
    setsid "$wrapper" < /dev/null &
  else
    nohup "$wrapper" < /dev/null &
  fi
  echo $! > "$PID_FILE"
}

supervisor_stop() {
  local sentinel="$CTI_HOME/runtime/stop-sentinel"
  local pid
  pid=$(read_pid)
  if [ -z "$pid" ]; then echo "No bridge running"; return 0; fi

  # Signal the respawn wrapper to stop looping
  touch "$sentinel"

  if pid_alive "$pid"; then
    kill "$pid"
    for _ in $(seq 1 15); do
      pid_alive "$pid" || break
      sleep 1
    done
    pid_alive "$pid" && kill -9 "$pid"
    echo "Bridge stopped"
  else
    echo "Bridge was not running (stale PID file)"
  fi
  rm -f "$PID_FILE" "$sentinel"
}

supervisor_is_managed() {
  # Linux fallback has no service manager; always false
  return 1
}

supervisor_status_extra() {
  : # No extra status for Linux fallback
}

supervisor_is_running() {
  local pid
  pid=$(read_pid)
  pid_alive "$pid"
}
