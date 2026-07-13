#!/usr/bin/env bash
# stop-all.sh — tear down the unified Sovereign stack
set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PID_DIR="${ROOT}/.stack-pids"

echo "══════════════════════════════════════════════════"
echo "  STOPPING SOVEREIGN STACK"
echo "══════════════════════════════════════════════════"

# Earth (bridge + vite)
bash "${HOME}/projects/sovereign-engine/stop-earth.sh" 2>/dev/null || true

# Hub
if [[ -f "${ROOT}/.hub.pid" ]]; then
  kill "$(cat "${ROOT}/.hub.pid")" 2>/dev/null || true
  rm -f "${ROOT}/.hub.pid"
  echo "  stopped command hub"
fi
if command -v fuser >/dev/null 2>&1; then
  fuser -k 5090/tcp 2>/dev/null || true
fi

# Optional pids from start-all
if [[ -d "$PID_DIR" ]]; then
  for f in "$PID_DIR"/*.pid; do
    [[ -f "$f" ]] || continue
    pid="$(cat "$f" 2>/dev/null || true)"
    name="$(basename "$f" .pid)"
    if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      echo "  stopped ${name} (pid ${pid})"
    fi
    rm -f "$f"
  done
fi

# God mode / aether leftovers by cmdline
while read -r pid; do
  cmd=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)
  if echo "$cmd" | grep -qE 'run_godmode|godmode_server|aether_core_launcher'; then
    kill "$pid" 2>/dev/null || true
    echo "  stopped leftover $pid"
  fi
done < <(pgrep -x python3 2>/dev/null || true)

# Voice docker (optional)
if [[ -f "${HOME}/sovereign_voice/docker-compose.yml" ]] && command -v docker >/dev/null 2>&1; then
  (cd "${HOME}/sovereign_voice" && docker compose down) 2>/dev/null || true
fi

rm -f /dev/shm/sovereign_stack.json 2>/dev/null || true

echo "Done."
echo "Start again: bash ~/projects/sovereign-command-hub/start-all.sh"
