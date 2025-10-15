#!/usr/bin/env python3

import json
from pathlib import Path
import sys

INPUT = Path("./servers.json")
OUTPUT = Path("./servers.firejail.json")
PROFILES_DIR = Path("./profiles")
DEFAULT_PROFILE = PROFILES_DIR / "firejail.profile"


def main() -> int:
    if not INPUT.exists():
        print(f"Error: input file not found: {INPUT}", file=sys.stderr)
        return 1
    try:
        data = json.loads(INPUT.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        print(f"Error: invalid JSON in {INPUT}: {e}", file=sys.stderr)
        return 1

    servers = data.get("mcpServers")
    if not isinstance(servers, dict):
        print("Error: .mcpServers object missing in input JSON", file=sys.stderr)
        return 1

    out_servers = {}
    for name, cfg in servers.items():
        if not isinstance(cfg, dict):
            continue
        cmd = cfg.get("command")
        args = cfg.get("args", [])
        if not isinstance(cmd, str) or not cmd:
            continue
        if not isinstance(args, list):
            args = [str(args)]

        per_server = PROFILES_DIR / f"{name}.profile"
        npm_profile = PROFILES_DIR / "npm.profile"
        if per_server.exists():
            profile_path = per_server
        elif cmd in ("npm", "npx") and npm_profile.exists():
            profile_path = npm_profile
        else:
            profile_path = DEFAULT_PROFILE

        out_servers[name] = {
            "command": "firejail",
            # Profile argument MUST be the first argument to firejail
            "args": [f"--profile={str(profile_path)}", cmd, *args],
        }

    OUTPUT.write_text(json.dumps({"mcpServers": out_servers}, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
