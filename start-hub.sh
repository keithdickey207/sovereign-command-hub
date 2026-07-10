#!/usr/bin/env bash
# Sovereign Command Hub — single entry dashboard for the whole stack
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
PORT="${SOVEREIGN_HUB_PORT:-5090}"
HOST="${SOVEREIGN_HUB_HOST:-0.0.0.0}"
START_EARTH=0
DAEMON=0
for arg in "$@"; do
  case "$arg" in
    --with-earth) START_EARTH=1 ;;
    --daemon) DAEMON=1 ;;
    --port=*) PORT="${arg#--port=}" ;;
  esac
done
mkdir -p "$ROOT/c2"
for f in "$HOME/04901_c2_tactical_engine_dashboard.html" "$HOME/c2_dashboard.html"; do
  [[ -f "$f" ]] && ln -sfn "$f" "$ROOT/c2/$(basename "$f")"
done
if [[ "$START_EARTH" -eq 1 ]]; then
  bash "$HOME/projects/sovereign-engine/start-earth.sh" --daemon || true
fi
echo "SOVEREIGN COMMAND HUB → http://localhost:${PORT}"
cd "$ROOT"
if [[ "$DAEMON" -eq 1 ]]; then
  nohup python3 -m http.server "$PORT" --bind "$HOST" >> "$ROOT/hub.log" 2>&1 &
  echo $! > "$ROOT/.hub.pid"
  exit 0
fi
exec python3 -m http.server "$PORT" --bind "$HOST"
