# Sovereign Command Hub

**One dashboard for the entire Sovereign / 04901 stack.**

| | |
|---|---|
| **URL** | http://localhost:5090 |
| **Earth UI** | http://localhost:5173 |
| **License** | [MIT](LICENSE) |
| **Operator** | Keith Alan Dickey — WSDS / 04901 Studio |

## Quick start — all projects as ONE

```bash
# Link + run the whole stack
bash ~/start-sovereign.sh
# or:
bash ~/projects/sovereign-command-hub/start-all.sh

# Optional extras (God Mode :8771, Aether, Voice)
bash ~/start-sovereign.sh --full

# Status / stop
bash ~/start-sovereign.sh --status
bash ~/projects/sovereign-command-hub/stop-all.sh
```

### What gets linked

| Layer | Projects | How |
|-------|----------|-----|
| Core process | district bridge + **defense** + **earth** | In-process imports (one Python WS) |
| UI | Earth React :5173 + this hub :5090 | Daemon processes |
| Cyber | 04901-sentinel `defense_intel.py` | One-shot feed at start |
| Mesh | `/dev/shm/sovereign_mesh` + stack registry | Shared memory |
| Optional | demographic God Mode, aether, voice | `--full` |

### Hub only

```bash
bash ~/projects/sovereign-command-hub/start-hub.sh
bash ~/projects/sovereign-command-hub/start-hub.sh --with-earth
```

## What it shows

- All core repos (Earth, District, Defense, GNS, Demographic, Aether, Sentinel, Twin)
- Support systems (Narrative, Voice, C2 HTML, Sync tools)
- Port probes for Earth UI / hub
- One-liner for **MIT license + GitHub push** of the whole stack

## License / GitHub for everything

```bash
gh auth login
bash ~/projects/sovereign-engine/license-github.sh --status
bash ~/projects/sovereign-engine/license-github.sh          # license + push all
```

## Stack index

See `~/projects/SOVEREIGN_EARTH_ENGINE.md`.
