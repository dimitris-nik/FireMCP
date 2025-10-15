#!/usr/bin/env python3
import argparse
import json
import os
import sys
from pathlib import Path
from urllib.parse import quote

DEFAULT_BASE = "http://172.20.0.2:8080"
DEFAULT_PATH = "/servers"
DEFAULT_SUFFIX = "/sse"


def build_url(base: str, path: str, name: str, suffix: str) -> str:
    base = base.rstrip("/")
    path = "/" + path.strip("/")
    suffix = "/" + suffix.strip("/")
    return f"{base}{path}/{quote(name, safe='')}{suffix}"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Convert servers.json to mcp.json (SSE endpoints).",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("input", nargs="?", default="servers.json", help="Input servers.json")
    parser.add_argument("output", nargs="?", default="mcp.json", help="Output mcp.json")
    parser.add_argument("-b", "--base-url", default=None, help="Base URL (or BASE_URL env)")
    parser.add_argument("-p", "--proto-path", default=None, help="Protocol path (or PROTO_PATH env)")
    parser.add_argument("-s", "--suffix", default=None, help="Event-stream suffix (or EVENT_STREAM_SUFFIX env)")
    args = parser.parse_args()

    base_url = args.base_url or os.getenv("BASE_URL", DEFAULT_BASE)
    proto_path = args.proto_path or os.getenv("PROTO_PATH", DEFAULT_PATH)
    suffix = args.suffix or os.getenv("EVENT_STREAM_SUFFIX", DEFAULT_SUFFIX)

    in_path = Path(args.input)
    out_path = Path(args.output)

    if not in_path.exists():
        print(f"Error: input file not found: {in_path}", file=sys.stderr)
        return 1

    try:
        with in_path.open("r", encoding="utf-8") as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        print(f"Error: invalid JSON in {in_path}: {e}", file=sys.stderr)
        return 1

    servers = data.get("mcpServers")
    if not isinstance(servers, dict):
        print("Error: .mcpServers object missing in input JSON", file=sys.stderr)
        return 1

    out_servers = {}
    for name, cfg in servers.items():
        if isinstance(cfg, dict):
            out_servers[name] = {"url": build_url(base_url, proto_path, name, suffix)}

    out_obj = {"mcpServers": out_servers}

    with out_path.open("w", encoding="utf-8") as f:
        json.dump(out_obj, f, indent=2)
        f.write("\n")

    print(f"Wrote {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())