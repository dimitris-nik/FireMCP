#!/usr/bin/env bash
set -euo pipefail

echo "Configuring network..."
ip addr add 172.20.0.2/24 dev eth0
ip link set eth0 up
ip route add default via 172.20.0.1
echo "nameserver 8.8.8.8" > /etc/resolv.conf
export PATH="$HOME/.local/bin:$PATH"

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
    curl

  echo "Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"

  echo "Installing mcp-proxy..."
  uv tool install mcp-proxy
  echo "Installing mcp-scan..."
  uv tool install mcp-scan

  mkdir -p "$(dirname "$FLAG_FILE")"
  touch "$FLAG_FILE"
fi

echo "Scanning Server Configuration"
mcp-scan ./servers.json

echo "Starting mcp-proxy..."
mcp-proxy \
  --host=0.0.0.0 \
  --port=8080 \
  --named-server-config /root/servers.json

