#!/usr/bin/env bash
set -euo pipefail

echo "Configuring network..."
ip addr add 172.20.0.2/24 dev eth0
ip link set eth0 up
ip route add default via 172.20.0.1
echo "nameserver 8.8.8.8" > /etc/resolv.conf

echo "Installing uv..."
curl -LsSf https://astral.sh/uv/install.sh | sh

echo "Installing firejail..."
export DEBIAN_FRONTEND=noninteractive
apt update -y
apt install -y firejail

echo "Installing mcp-proxy..."
uv tool install mcp-proxy

echo "Starting mcp-proxy..."
mcp-proxy \
  --host=0.0.0.0 \
  --port=8080 \
  --named-server fetch "firejail --noprofile uvx mcp-server-fetch" \
  --named-server fetch2 "firejail --noprofile uvx mcp-server-fetch"

