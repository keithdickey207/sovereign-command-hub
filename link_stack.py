#!/usr/bin/env python3
"""
Link all Sovereign projects into one runtime registry.

- Seeds /dev/shm/sovereign_mesh
- Writes /dev/shm/sovereign_stack.json (live status of every project)
- Exports PYTHONPATH fragments for bridge imports
- Confirms in-process links (defense + earth already loaded by district_bridge)

Keith Alan Dickey — WSDS / 04901 Studio
"""

from __future__ import annotations

import json
import os
import socket
import time
import urllib.error
import urllib.request
from pathlib import Path

HOME = Path.home()
STACK_JSON = HOME / "projects" / "sovereign-command-hub" / "stack.json"
COMMAND_NODE_JSON = HOME / "projects" / "sovereign-earth" / "config" / "command_node.json"
SHM_STACK = Path("/dev/shm/sovereign_stack.json")
SHM_MESH = Path("/dev/shm/sovereign_mesh")
SHM_DEFENSE = Path("/dev/shm/sovereign_defense.json")
SHM_COMMAND_NODE = Path("/dev/shm/sovereign_command_node.json")


def expand(p: str | None) -> Path | None:
    if not p:
        return None
    return Path(os.path.expanduser(p)).resolve()


def port_open(port: int, host: str = "127.0.0.1") -> bool:
    try:
        with socket.create_connection((host, port), timeout=0.4):
            return True
    except OSError:
        return False


def http_ok(url: str, timeout: float = 1.0) -> bool:
    try:
        with urllib.request.urlopen(url, timeout=timeout) as r:
            return 200 <= r.status < 500
    except (urllib.error.URLError, TimeoutError, OSError):
        return False


def seed_mesh() -> None:
    SHM_MESH.mkdir(parents=True, exist_ok=True)
    (SHM_MESH / "topics").mkdir(exist_ok=True)
    heartbeat = {
        "type": "mesh.heartbeat",
        "source": "link_stack",
        "node": os.environ.get("SOVEREIGN_NODE_ID", "04901_command"),
        "host_id": os.environ.get("SOVEREIGN_HOST_ID", "dell-3910-flex"),
        "role": os.environ.get("SOVEREIGN_ROLE", "main_command_node"),
        "primary": os.environ.get("SOVEREIGN_COMMAND_NODE_PRIMARY", "1") == "1",
        "ts": time.time(),
        "status": "linked",
    }
    (SHM_MESH / "heartbeat.json").write_text(json.dumps(heartbeat, indent=2))


def load_command_node() -> dict | None:
    """Load + stamp the Dell 3910 Flex main command node identity into SHM."""
    path = COMMAND_NODE_JSON
    if not path.exists():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    data["runtime"] = {
        "hostname": socket.gethostname(),
        "node_id": os.environ.get("SOVEREIGN_NODE_ID", data.get("node_id", "04901_command")),
        "host_id": os.environ.get("SOVEREIGN_HOST_ID", data.get("host_id", "dell-3910-flex")),
        "hub_ip": os.environ.get("SOVEREIGN_HUB_IP")
        or os.environ.get("GODS_EYE_HUB_IP")
        or (data.get("network") or {}).get("tailscale_ip"),
        "primary": True,
        "role": "main_command_node",
        "ts": time.time(),
        "ts_iso": time.strftime("%Y-%m-%dT%H:%M:%S"),
    }
    try:
        SHM_COMMAND_NODE.write_text(json.dumps(data, indent=2))
    except OSError:
        pass
    return data


def probe_service(svc: dict) -> dict:
    port = svc.get("port")
    check = svc.get("check")
    path = expand(svc.get("path"))
    start_mode = svc.get("start")
    status = "unknown"
    detail = ""

    if path is not None:
        if path.exists():
            detail = str(path)
            # path present: linked or ready depending on start mode
            if start_mode in ("link_only", "once", None):
                status = "linked"
            else:
                status = "idle"
        else:
            status = "missing_path"
            detail = f"missing {path}"
    elif start_mode is None and not port:
        status = "idle"

    if port:
        if port_open(int(port)):
            status = "live"
        else:
            status = "down" if svc.get("required") else (status if status != "unknown" else "idle")

    if check:
        if http_ok(check):
            status = "live"
        elif status != "live":
            status = "down" if svc.get("required") else (status if status != "unknown" else "idle")

    # SHM special cases
    if svc["id"] == "mesh":
        status = "live" if SHM_MESH.exists() else "down"
        detail = str(SHM_MESH)
    if svc["id"] == "bridge" and port_open(8765):
        status = "live"
        # confirm defense/earth importable
        try:
            import sys

            sys.path.insert(0, str(HOME / "projects" / "sovereign-defense"))
            sys.path.insert(0, str(HOME / "projects" / "sovereign-earth"))
            import defense_core  # noqa: F401
            import platform_status  # noqa: F401

            detail = "bridge+defense+earth imports OK"
        except Exception as e:
            detail = f"bridge up; import warn: {e}"

    return {
        "id": svc["id"],
        "name": svc["name"],
        "role": svc["role"],
        "group": svc.get("group"),
        "required": bool(svc.get("required")),
        "port": port,
        "path": str(path) if path else None,
        "status": status,
        "detail": detail,
        "links": svc.get("links") or [],
    }


def build_registry() -> dict:
    stack = json.loads(STACK_JSON.read_text())
    seed_mesh()
    command_node = load_command_node()
    services = [probe_service(s) for s in stack["services"]]
    live = sum(1 for s in services if s["status"] == "live")
    linked = sum(1 for s in services if s["status"] in ("live", "linked", "idle"))
    required_down = [s["id"] for s in services if s["required"] and s["status"] not in ("live", "linked")]

    # PYTHONPATH for all project roots
    roots = []
    for s in stack["services"]:
        p = expand(s.get("path"))
        if p and p.exists():
            roots.append(str(p))
    # known import roots used by bridge
    for extra in (
        HOME / "projects" / "sovereign-defense",
        HOME / "projects" / "sovereign-earth",
        HOME / "projects" / "district_04901_grid",
        HOME / "open-source-galactic-flight-and-time-navigation-system-with-AI-",
    ):
        if extra.exists() and str(extra) not in roots:
            roots.append(str(extra))

    cn = stack.get("main_command_node") or {}
    if command_node:
        cn = {
            **cn,
            "host_id": command_node.get("host_id"),
            "display_name": command_node.get("display_name"),
            "is_primary": True,
            "role": "main_command_node",
            "runtime": command_node.get("runtime"),
            "hardware": command_node.get("hardware"),
            "os": command_node.get("os"),
            "network": command_node.get("network"),
            "authority": command_node.get("authority"),
        }

    registry = {
        "platform": stack["platform"],
        "version": stack["version"],
        "operator": stack["operator"],
        "who_i_am": stack.get("who_i_am"),
        "mission_statement": stack.get("mission_statement"),
        "mission_short": stack.get("mission_short"),
        "doctrine": stack.get("doctrine"),
        "anchor": stack["anchor"],
        "license": stack.get("license", "MIT"),
        "main_command_node": cn,
        "ts": time.time(),
        "ts_iso": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "urls": stack["links"],
        "summary": {
            "services_total": len(services),
            "live": live,
            "linked_or_ready": linked,
            "required_down": required_down,
            "healthy": len(required_down) == 0,
            "command_node": "dell-3910-flex",
            "command_node_primary": True,
        },
        "pythonpath": roots,
        "services": services,
        "defense_shm": SHM_DEFENSE.exists(),
        "mesh_shm": SHM_MESH.exists(),
        "command_node_shm": SHM_COMMAND_NODE.exists(),
    }
    return registry


def write_registry(reg: dict | None = None) -> Path:
    reg = reg or build_registry()
    try:
        SHM_STACK.write_text(json.dumps(reg, indent=2))
    except OSError:
        # fallback to project dir if /dev/shm not writable
        alt = HOME / "projects" / "sovereign-command-hub" / "stack_status.json"
        alt.write_text(json.dumps(reg, indent=2))
        return alt
    return SHM_STACK


def print_status(reg: dict) -> None:
    s = reg["summary"]
    cn = reg.get("main_command_node") or {}
    print("══ SOVEREIGN STACK LINK STATUS ══")
    print(f"  platform: {reg['platform']} v{reg['version']}")
    print(f"  healthy:  {s['healthy']}  live={s['live']}/{s['services_total']}")
    print(
        f"  command:  {cn.get('display_name') or cn.get('host_id') or 'dell-3910-flex'} "
        f"· PRIMARY · code exec + updates"
    )
    if s["required_down"]:
        print(f"  REQUIRED DOWN: {', '.join(s['required_down'])}")
    print("")
    for svc in reg["services"]:
        mark = {
            "live": "●",
            "linked": "○",
            "idle": "·",
            "down": "✗",
            "missing_path": "?",
        }.get(svc["status"], "?")
        port = f":{svc['port']}" if svc["port"] else "     "
        print(f"  {mark} {svc['id']:16} {port:6} {svc['status']:12}  {svc['name']}")
    print("")
    u = reg["urls"]
    print(f"  Hub:    {u['command_hub']}")
    print(f"  Earth:  {u['earth_ui']}")
    print(f"  WS:     {u['bridge_ws']}")
    print(f"  SHM:    {u['stack_shm']}")
    if u.get("gods_eye_tailscale"):
        print(f"  Eye TS: {u['gods_eye_tailscale']}")
    print("═══════════════════════════════")


def main() -> int:
    import argparse

    ap = argparse.ArgumentParser(description="Link / status Sovereign stack")
    ap.add_argument("--json", action="store_true", help="print registry JSON")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    reg = build_registry()
    path = write_registry(reg)
    if args.json:
        print(json.dumps(reg, indent=2))
    elif not args.quiet:
        print_status(reg)
        print(f"  wrote {path}")
    return 0 if reg["summary"]["healthy"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
