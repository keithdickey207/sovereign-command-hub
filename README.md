# Sovereign Command Hub

**One dashboard for the entire Sovereign / 04901 stack.**

| | |
|---|---|
| **URL** | http://localhost:5090 |
| **Earth UI** | http://localhost:5173 |
| **License** | [MIT](LICENSE) |
| **Operator** | Keith Alan Dickey — WSDS / 04901 Studio |

## Quick start

```bash
# Hub only
bash ~/projects/sovereign-command-hub/start-hub.sh

# Hub + Earth Engine (bridge + React map)
bash ~/projects/sovereign-command-hub/start-hub.sh --with-earth

# Background
bash ~/projects/sovereign-command-hub/start-hub.sh --with-earth --daemon
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
