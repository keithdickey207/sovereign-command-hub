#!/usr/bin/env bash
# start-all.sh — run the entire Sovereign stack as ONE system
# Keith Alan Dickey — WSDS / 04901 Studio
#
# Usage:
#   bash ~/projects/sovereign-command-hub/start-all.sh
#   bash ~/projects/sovereign-command-hub/start-all.sh --full      # + godmode + aether
#   bash ~/projects/sovereign-command-hub/start-all.sh --core-only
#   bash ~/projects/sovereign-command-hub/start-all.sh --status
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
HOME_DIR="${HOME}"
PY="${HOME_DIR}/sovereign_venv/bin/python"
[[ -x "$PY" ]] || PY="python3"
export PYTHON="${PY}"
# Dell OptiPlex 3910 · Chrome OS Flex (beta) · MAIN COMMAND NODE
if [[ -f "${HOME_DIR}/.config/sovereign/command-node.env" ]]; then
  # shellcheck disable=SC1091
  source "${HOME_DIR}/.config/sovereign/command-node.env"
fi
export SOVEREIGN_NODE_ID="${SOVEREIGN_NODE_ID:-04901_command}"
export SOVEREIGN_HOST_ID="${SOVEREIGN_HOST_ID:-dell-3910-flex}"
export SOVEREIGN_ROLE="${SOVEREIGN_ROLE:-main_command_node}"
export SOVEREIGN_COMMAND_NODE_PRIMARY=1
export PYTHONUNBUFFERED=1

# Unified PYTHONPATH — all projects importable as one
export PYTHONPATH="${HOME_DIR}/projects/district_04901_grid:${HOME_DIR}/projects/sovereign-defense:${HOME_DIR}/projects/sovereign-earth:${HOME_DIR}/open-source-galactic-flight-and-time-navigation-system-with-AI-:${HOME_DIR}/projects/aether:${HOME_DIR}/projects/04901-sentinel:${HOME_DIR}/projects/sovereign-demographic-engine:${PYTHONPATH:-}"

PID_DIR="${ROOT}/.stack-pids"
LOG_DIR="${ROOT}/logs"
mkdir -p "$PID_DIR" "$LOG_DIR"

FULL=0
CORE_ONLY=0
STATUS_ONLY=0
NO_FETCH=0

for arg in "$@"; do
  case "$arg" in
    --full) FULL=1 ;;
    --core-only) CORE_ONLY=1 ;;
    --status) STATUS_ONLY=1 ;;
    --no-fetch) NO_FETCH=1 ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
  esac
done

banner() {
  echo ""
  echo "══════════════════════════════════════════════════"
  echo "  SOVEREIGN STACK — ONE SYSTEM"
  echo "  MAIN COMMAND NODE · Dell OptiPlex 3910"
  echo "  Chrome OS Flex (beta) · penguin / Crostini"
  echo "  04901 Command · WSDS · code exec + updates HERE"
  echo "══════════════════════════════════════════════════"
  echo ""
}

port_up() {
  ss -lnt 2>/dev/null | grep -qE ":${1}\\s" && return 0
  return 1
}

start_bg() {
  local name="$1"; shift
  local log="${LOG_DIR}/${name}.log"
  # skip if pid alive
  if [[ -f "${PID_DIR}/${name}.pid" ]]; then
    local old
    old="$(cat "${PID_DIR}/${name}.pid")"
    if kill -0 "$old" 2>/dev/null; then
      echo "  [=] ${name} already running (pid ${old})"
      return 0
    fi
  fi
  nohup "$@" >>"$log" 2>&1 &
  echo $! >"${PID_DIR}/${name}.pid"
  echo "  [+] ${name}  pid $(cat "${PID_DIR}/${name}.pid")  log ${log}"
}

if [[ "$STATUS_ONLY" -eq 1 ]]; then
  banner
  "$PY" "$ROOT/link_stack.py"
  exit $?
fi

banner
echo "[0/6] Linking all projects (PYTHONPATH + SHM registry)..."
"$PY" "$ROOT/link_stack.py" --quiet || true
echo "  PYTHONPATH set across district / defense / earth / gns / aether / sentinel / demographic"
echo "  Node: ${SOVEREIGN_NODE_ID}  host=${SOVEREIGN_HOST_ID}  role=${SOVEREIGN_ROLE}"
if [[ -x "${HOME_DIR}/bin/sovereign-command-node" ]]; then
  "${HOME_DIR}/bin/sovereign-command-node" >/dev/null 2>&1 || true
elif [[ -f "${HOME_DIR}/projects/sovereign-earth/config/command_node.json" ]]; then
  cp "${HOME_DIR}/projects/sovereign-earth/config/command_node.json" /dev/shm/sovereign_command_node.json 2>/dev/null || true
fi

# --- 1. Foundation ---
echo ""
echo "[1/6] Foundation"
if port_up 11434; then
  echo "  [●] Ollama live :11434"
else
  echo "  [·] Ollama not listening (optional — AI ops degraded)"
fi
"$PY" -c "from pathlib import Path; Path('/dev/shm/sovereign_mesh').mkdir(parents=True, exist_ok=True); print('  [+] Mesh SHM ready')"

# --- 2. Cyber feed into defense ---
echo ""
echo "[2/6] Sentinel → defense cyber layer"
if [[ -f "${HOME_DIR}/projects/04901-sentinel/defense_intel.py" ]]; then
  "$PY" "${HOME_DIR}/projects/04901-sentinel/defense_intel.py" >>"${LOG_DIR}/sentinel-intel.log" 2>&1 || true
  echo "  [+] defense_intel.py ran (CVE feed → SHM/defense)"
else
  echo "  [·] sentinel defense_intel.py not found"
fi

# --- 3. Core: Earth = bridge (defense+earth linked in-process) + React UI ---
echo ""
echo "[3/6] Core — District Bridge + Defense + Earth UI"
EARTH_FLAGS=(--daemon)
[[ "$NO_FETCH" -eq 1 ]] && EARTH_FLAGS+=(--no-fetch)
if port_up 8765 && port_up 5173; then
  echo "  [=] Core already up (:8765 + :5173)"
else
  bash "${HOME_DIR}/projects/sovereign-engine/start-earth.sh" "${EARTH_FLAGS[@]}"
fi

# wait briefly for ports
for i in 1 2 3 4 5 6 7 8; do
  port_up 8765 && port_up 5173 && break
  sleep 1
done

# --- 4. Command Hub ---
echo ""
echo "[4/6] Command Hub (one dashboard)"
if port_up 5090; then
  echo "  [●] Hub already http://localhost:5090"
else
  bash "${ROOT}/start-hub.sh" --daemon
  sleep 0.6
  if port_up 5090; then
    echo "  [●] Hub http://localhost:5090"
  else
    bash "${ROOT}/start-hub.sh" --force --daemon || true
    sleep 0.6
    port_up 5090 && echo "  [●] Hub http://localhost:5090" || echo "  [!] Hub failed — check ${ROOT}/hub.log"
  fi
fi

# --- 5. Optional services ---
echo ""
echo "[5/6] Optional services"
if [[ "$CORE_ONLY" -eq 1 ]]; then
  echo "  (skipped — --core-only)"
else
  # Demographic God Mode
  if [[ "$FULL" -eq 1 ]] || [[ "${SOVEREIGN_START_GODMODE:-0}" == "1" ]]; then
    if port_up 8771; then
      echo "  [=] God Mode already :8771"
    elif [[ -f "${HOME_DIR}/projects/sovereign-demographic-engine/scripts/run_godmode.py" ]]; then
      start_bg godmode "$PY" "${HOME_DIR}/projects/sovereign-demographic-engine/scripts/run_godmode.py" --host 0.0.0.0 --port 8771
    fi
  else
    echo "  [·] God Mode idle (enable: --full or SOVEREIGN_START_GODMODE=1)"
  fi

  # Aether
  if [[ "$FULL" -eq 1 ]] || [[ "${SOVEREIGN_START_AETHER:-0}" == "1" ]]; then
    if [[ -f "${HOME_DIR}/projects/aether/aether_core_launcher.py" ]]; then
      start_bg aether "$PY" "${HOME_DIR}/projects/aether/aether_core_launcher.py" --mode full
    fi
  else
    echo "  [·] Aether idle (enable: --full)"
  fi

  # Voice (docker)
  if [[ "$FULL" -eq 1 ]] || [[ "${SOVEREIGN_START_VOICE:-0}" == "1" ]]; then
    if command -v docker >/dev/null 2>&1 && [[ -f "${HOME_DIR}/sovereign_voice/docker-compose.yml" ]]; then
      (cd "${HOME_DIR}/sovereign_voice" && docker compose up -d) >>"${LOG_DIR}/voice.log" 2>&1 || true
      echo "  [+] Voice docker compose up"
    else
      echo "  [·] Voice skipped (no docker or compose)"
    fi
  else
    echo "  [·] Voice idle (enable: --full)"
  fi
fi

# --- 6. Final registry ---
echo ""
echo "[6/6] Final stack registry"
sleep 1
"$PY" "$ROOT/link_stack.py"

echo ""
echo "  ┌─────────────────────────────────────────────────┐"
echo "  │  ONE SYSTEM — open these                        │"
echo "  │                                                 │"
echo "  │  Command Hub  http://localhost:5090             │"
echo "  │  Earth UI     http://localhost:5173             │"
echo "  │  Bridge WS    ws://localhost:8765               │"
if port_up 8771; then
echo "  │  God Mode     http://localhost:8771             │"
fi
echo "  │                                                 │"
echo "  │  Stop all:  bash ~/projects/sovereign-command-hub/stop-all.sh"
echo "  │  Status:    bash ~/projects/sovereign-command-hub/start-all.sh --status"
echo "  └─────────────────────────────────────────────────┘"
echo ""
