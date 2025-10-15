#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

echo "Configuring network..."
ip addr replace 172.20.0.2/24 dev eth0
ip link set eth0 up
ip route replace default via 172.20.0.1
echo "nameserver 8.8.8.8" > /etc/resolv.conf

FLAG_FILE="/var/lib/first_boot_flag"

if [[ ! -f "$FLAG_FILE" ]]; then
  echo "Installing dependencies (firejail, nodejs, npm, ca-certificates)..."
  export DEBIAN_FRONTEND=noninteractive
  export DEBIAN_PRIORITY=critical
  apt-get update -yq
  apt-get install -yq --no-install-recommends \
    firejail \
    nodejs \
    npm \
    ca-certificates \
    curl \
    haveged

  echo "Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"

  echo "Installing mcp-proxy..."
  uv tool install mcp-proxy
  echo "Installing mcp-scan..."
  uv tool install mcp-scan
  mkdir -p /root/.npm
  mkdir -p "$(dirname "$FLAG_FILE")"
  touch "$FLAG_FILE"
fi

echo "Scanning Server Configuration"
mcp-scan /root/servers.json

# Trap Ctrl+C (SIGINT) to reboot
trap 'echo "Ctrl+C detected, rebooting..."; reboot' SIGINT


echo "Starting mcp-proxy..."
mcp-proxy \
  --host=0.0.0.0 \
  --port=8080 \
  --named-server-config /root/servers.firejail.json



