#!/usr/bin/env bash
# Sovereign Command Hub — single entry dashboard for the whole stack
# Keith Alan Dickey — WSDS / 04901 Studio
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
    -h|--help)
      echo "Usage: $0 [--with-earth] [--daemon] [--port=5090]"
      echo "  --with-earth  also launch start-earth.sh --daemon"
      echo "  Open: http://localhost:${PORT}"
      exit 0
      ;;
  esac
done

# Symlink home C2 dashboards into hub for static serve
mkdir -p "$ROOT/c2"
for f in \
  "$HOME/04901_c2_tactical_engine_dashboard.html" \
  "$HOME/c2_dashboard.html"
do
  if [[ -f "$f" ]]; then
    ln -sfn "$f" "$ROOT/c2/$(basename "$f")"
  fi
done

if [[ "$START_EARTH" -eq 1 ]]; then
  echo "[*] Starting Earth Engine (daemon)..."
  bash "$HOME/projects/sovereign-engine/start-earth.sh" --daemon || {
    echo "[!] Earth start failed — hub will still serve"
  }
fi

echo "=============================================="
echo "  SOVEREIGN COMMAND HUB"
echo "  http://localhost:${PORT}"
echo "  Earth UI: http://localhost:5173"
echo "=============================================="
echo ""
echo "  License/GitHub: bash ~/projects/sovereign-engine/license-github.sh --status"
echo "  Full stack:     bash ~/projects/sovereign-engine/start-earth.sh"
echo ""

cd "$ROOT"
if [[ "$DAEMON" -eq 1 ]]; then
  nohup python3 -m http.server "$PORT" --bind "$HOST" >> "$ROOT/hub.log" 2>&1 &
  echo $! > "$ROOT/.hub.pid"
  echo "  Daemon PID $(cat "$ROOT/.hub.pid")  log: $ROOT/hub.log"
  exit 0
fi

exec python3 -m http.server "$PORT" --bind "$HOST"
