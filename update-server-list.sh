#!/usr/bin/env bash
set -euo pipefail

# Variables
ROOTFS_IMG="rootfs.ext4"
MOUNT_DIR="mnt"
SERVER_CONFIG="servers.json"
INIT_SCRIPT="initialize.sh"

# Check prerequisites
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

# Mount image
echo "[] Mounting rootfs image..."
mkdir -p "$MOUNT_DIR"
sudo mount -o loop "$ROOTFS_IMG" "$MOUNT_DIR"

# Sync servers.json
echo "[] Syncing $SERVER_CONFIG to rootfs..."
sudo cp "$SERVER_CONFIG" "$MOUNT_DIR/root/"

# Sync initialize.sh to /root and ensure it's executable
echo "[] Syncing $INIT_SCRIPT to rootfs..."
sudo cp "$INIT_SCRIPT" "$MOUNT_DIR/root/"
sudo chmod +x "$MOUNT_DIR/root/$INIT_SCRIPT"

# Unmount
echo "[] Unmounting rootfs image..."
sudo umount "$MOUNT_DIR"
rmdir "$MOUNT_DIR"

echo "Done! Synced $SERVER_CONFIG and $INIT_SCRIPT into $ROOTFS_IMG:/root/"

