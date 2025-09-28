# FireMCP

Minimal harness to build a Firecracker image and run MCP servers inside the VM.

## Requirements

- Python 3
- firectl or firecracker (one of them on PATH)
- iproute2 (ip), iptables, and sudo for TAP/NAT setup
- bash and standard Linux utilities (used by the helper scripts)

## Quick start

- First run (builds images and starts the VM):
	- `./firemcp.py`
- Check status:
	- `./firemcp.py status`

## Commands (short list)

- `./firemcp.py` or `./firemcp.py auto` — Build on first run, else start the VM.
- `./firemcp.py start` — Start the VM now.
- `./firemcp.py images` — Build/rebuild kernel and rootfs (also starts the VM).
- `./firemcp.py update` — Sync `servers.json` into the rootfs.
- `./firemcp.py gen-config [servers.json] [mcp.json] [-b BASE] [-p PATH] [-s SUFFIX]` — Generate `mcp.json` from `servers.json`.
- `./firemcp.py purge` — Delete kernel/rootfs images only (no network changes).

## Configure servers

- Edit `servers.json` to enable/disable servers. The `update` command will sync this into the VM's rootfs when needed. An update is automatically triggered when starting the VM.

## Generate client config (mcp.json)

- Create an MCP client config from `servers.json` for tools like Cursor or Claude Desktop:
	- `./firemcp.py gen-config` — uses defaults and writes `mcp.json`
	- Or specify details explicitly:
		- `./firemcp.py gen-config servers.json mcp.json -b http://172.20.0.2:8080 -p /servers -s /sse`

Notes
- Privileged steps are handled inside the shell scripts (may prompt for sudo).
- Manual scripts are available if you prefer:
	- `get-imgs.sh` — build images
	- `start.sh` — start the VM
	- `update-server-list.sh` — copy `servers.json` into the rootfs

