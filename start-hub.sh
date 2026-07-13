#!/usr/bin/env bash
# Sovereign Command Hub — single entry dashboard for the whole stack
# Keith Alan Dickey — WSDS / 04901 Studio
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PORT="${SOVEREIGN_HUB_PORT:-5090}"
HOST="${SOVEREIGN_HUB_HOST:-0.0.0.0}"
START_EARTH=0
DAEMON=0
FORCE=0

for arg in "$@"; do
  case "$arg" in
    --with-earth) START_EARTH=1 ;;
    --daemon) DAEMON=1 ;;
    --force|--restart) FORCE=1 ;;
    --port=*) PORT="${arg#--port=}" ;;
    -h|--help)
      echo "Usage: $0 [--with-earth] [--daemon] [--force] [--port=5090]"
      echo "  --with-earth  also launch start-earth.sh --daemon"
      echo "  --daemon      run hub in background"
      echo "  --force       kill existing hub on this port, then start"
      echo "  Open: http://localhost:${PORT}"
      exit 0
      ;;
  esac
done

port_in_use() {
  local p="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -lnt 2>/dev/null | grep -qE ":${p}\\s"
    return $?
  fi
  # fallback
  python3 -c "import socket;s=socket.socket();r=s.connect_ex(('127.0.0.1',${p}));s.close();raise SystemExit(0 if r==0 else 1)" 2>/dev/null
}

stop_hub() {
  if [[ -f "$ROOT/.hub.pid" ]]; then
    local old
    old="$(cat "$ROOT/.hub.pid" 2>/dev/null || true)"
    if [[ -n "${old:-}" ]] && kill -0 "$old" 2>/dev/null; then
      kill "$old" 2>/dev/null || true
      sleep 0.5
    fi
    rm -f "$ROOT/.hub.pid"
  fi
  # free port if something else still holds it
  if command -v fuser >/dev/null 2>&1; then
    fuser -k "${PORT}/tcp" 2>/dev/null || true
  fi
  sleep 0.3
}

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

# Already running?
if port_in_use "$PORT"; then
  if [[ "$FORCE" -eq 1 ]]; then
    echo "[*] Port ${PORT} in use — restarting hub (--force)"
    stop_hub
  else
    echo "=============================================="
    echo "  SOVEREIGN COMMAND HUB (already running)"
    echo "  http://localhost:${PORT}"
    echo "  Earth UI: http://localhost:5173"
    echo "  WebSocket: ws://localhost:8765"
    echo "=============================================="
    echo ""
    echo "  Restart hub:  bash $0 --force"
    echo "  Stop hub:     kill \$(cat $ROOT/.hub.pid 2>/dev/null) 2>/dev/null"
    echo ""
    # quick health
    if curl -sf -o /dev/null "http://127.0.0.1:${PORT}/"; then
      echo "  Status: OK (HTTP 200)"
    else
      echo "  Status: port open but HTTP check failed — try: bash $0 --force"
    fi
    exit 0
  fi
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
  sleep 0.5
  echo "  Daemon PID $(cat "$ROOT/.hub.pid")  log: $ROOT/hub.log"
  exit 0
fi

# Foreground: also record pid so --force can stop it
python3 -m http.server "$PORT" --bind "$HOST" &
echo $! > "$ROOT/.hub.pid"
wait
