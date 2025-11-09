#!/usr/bin/env bash
set -euo pipefail

# Variables
ROOTFS_IMG="rootfs.ext4"
MOUNT_DIR="mnt"
SERVER_FIREJAIL_CONFIG="servers.firejail.json"
SERVER_CONFIG="servers.json"
INIT_SCRIPT="initialize.sh"
PROFILES_DIR="profiles"
WORKSPACE_DIR="${1:-}"

# Check prerequisites
if [[ ! -f "$SERVER_FIREJAIL_CONFIG" ]]; then
  echo "Error: $SERVER_FIREJAIL_CONFIG not found in current directory."
  exit 1
fi

if [[ ! -f "$SERVER_CONFIG" ]]; then
  echo "Error: $SERVER_CONFIG not found in current directory."
  exit 1
fi


if [[ ! -f "$ROOTFS_IMG" ]]; then
  echo "Error: $ROOTFS_IMG not found. Did you run the build script first?"
  exit 1
fi

# Also update initialize.sh if it exists
if [[ ! -f "$INIT_SCRIPT" ]]; then
  echo "Error: $INIT_SCRIPT not found in current directory."
  exit 1
fi

if [[ ! -d "$PROFILES_DIR" ]]; then
  echo "[!] Warning: $PROFILES_DIR directory not found; skipping profile sync"
fi


# If an external workspace directory is supplied, calculate its size
# and grow the rootfs image before mounting so there's enough space.
if [[ -n "$WORKSPACE_DIR" ]]; then
  if [[ ! -d "$WORKSPACE_DIR" ]]; then
    echo "Error: workspace directory not found: $WORKSPACE_DIR"
    exit 1
  fi
  echo "[] Calculating size of workspace directory '$WORKSPACE_DIR'..."
  WORKSPACE_BYTES=$(du -sb "$WORKSPACE_DIR" | cut -f1)
  # Add a safety slack (100 MiB)
  TOTAL_MB=$((WORKSPACE_BYTES / 1024 / 1024 + 100))
  echo "[] Workspace size: ${TOTAL_MB} MB. Increasing $ROOTFS_IMG size..."
  # Grow the image file. 
  sudo truncate -s +"${TOTAL_MB}M" "$ROOTFS_IMG"
fi

# Mount image
echo "[] Mounting rootfs image..."
mkdir -p "$MOUNT_DIR"
sudo mount -o loop "$ROOTFS_IMG" "$MOUNT_DIR"

# Sync servers.firejail.json and servers.json
echo "[] Syncing $SERVER_FIREJAIL_CONFIG to rootfs..."
sudo cp "$SERVER_FIREJAIL_CONFIG" "$MOUNT_DIR/root/"
echo "[] Syncing $SERVER_CONFIG to rootfs..."
sudo cp "$SERVER_CONFIG" "$MOUNT_DIR/root/"

# Sync initialize.sh to /root and ensure it's executable
echo "[] Syncing $INIT_SCRIPT to rootfs..."
sudo cp "$INIT_SCRIPT" "$MOUNT_DIR/root/"
sudo chmod +x "$MOUNT_DIR/root/$INIT_SCRIPT"

# Sync profiles directory if present
if [[ -d "$PROFILES_DIR" ]]; then
  echo "[] Syncing $PROFILES_DIR to rootfs..."
  sudo mkdir -p "$MOUNT_DIR/root/$PROFILES_DIR"
  sudo cp -a "$PROFILES_DIR/." "$MOUNT_DIR/root/$PROFILES_DIR/"
fi

# Sync external workspace directory if provided as first argument
if [[ -n "$WORKSPACE_DIR" ]]; then
  if [[ ! -d "$WORKSPACE_DIR" ]]; then
    echo "Error: workspace directory not found: $WORKSPACE_DIR"
    echo "[] Unmounting rootfs image..."
    sudo umount "$MOUNT_DIR" || true
    rmdir "$MOUNT_DIR" || true
    exit 1
  fi
  echo "[] Syncing workspace '$WORKSPACE_DIR' to rootfs:/mcp-workspace..."
  sudo mkdir -p "$MOUNT_DIR/mcp-workspace"
  sudo cp -a "$WORKSPACE_DIR/." "$MOUNT_DIR/mcp-workspace/"
fi

# Unmount
echo "[] Unmounting rootfs image..."
sudo umount "$MOUNT_DIR"
rmdir "$MOUNT_DIR"

echo "[] Sync complete!"
