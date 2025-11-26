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
- `./firemcp.py update` — Sync essential files into the rootfs.
- `./firemcp.py gen-config [servers.json] [mcp.json] [-b BASE] [-p PATH] [-s SUFFIX]` — Generate `mcp.json` from `servers.json`.
- `./firemcp.py purge` — Delete kernel/rootfs images only (no network changes).

## Configure servers

- Edit `servers.json` to enable/disable servers. The `update` command will sync this into the VM's rootfs when needed. An update is automatically triggered when starting the VM.

## Generate client config (mcp.json)

- Create an MCP client config from `servers.json` that points to the VM's MCP server endpoints and can be used by MCP clients (Claude Code, Cursor, VSCode, etc).
	- `./firemcp.py gen-config` — uses defaults and writes `mcp.json` based on `servers.json`.
	- Or specify details explicitly:
		- `./firemcp.py gen-config servers.json mcp.json -b http://172.20.0.2:8080 -p /servers -s /sse`

## Firejail profiles
FireMCP selects the best Firejail profile to use based on the MCP server command. To override, add `profiles/<server>.profile`. Profiles are synced to `/root/profiles` in the VM. To create profiles manually, check [Firejail Documentation](https://man7.org/linux/man-pages/man1/firejail.1.html).

Notes
- Privileged steps are handled inside the shell scripts (may prompt for sudo).
- Manual scripts are available if you prefer:
	- `get-imgs.sh` — build images
	- `start.sh` — start the VM
	- `sync-files.sh` — copy t
	
Here are the last **three sections rewritten, cleaned up, and made consistent**:

---

## MCP Scan

When the VM starts, FireMCP automatically performs an MCP scan using your current `server.json` configuration. This helps verify that all configured MCP servers are running correctly and reachable from the VM.

## Copy host directories into the VM

FireMCP can copy a directory from the host into the VM’s filesystem.
Running:

```
./firemcp.py [DIR_PATH]
```

will copy the specified directory into `/mcp-workspace` inside the VM. After the VM stops, the changes will be synced back to the host and a backup of the original directory will be created.
This is useful for MCP servers that require access to local files, datasets, or project directories.

## Connection to Claude Code, Cursor, and VSCode

Claude Code is configured to automatically start once FireMCP finishes initializing.
FireMCP also supports connecting through **Cursor** and **VSCode** via SSH tunnels.

To enable this, FireMCP copies a generated `mcp.json` file into the appropriate locations inside the VM so these clients can automatically detect and connect to the MCP servers.

You can connect your editor by SSHing into the VM:

```
ssh root@172.20.0.2
```

Once connected, Cursor or VSCode will be able to interact with the MCP servers running inside the VM.

