#!/usr/bin/env bash
set -euo pipefail

# ./move-to-host.sh /path/to/host/workspace

ROOTFS_IMG="rootfs.ext4"
MOUNT_DIR="mnt"
VM_WORK_DIR="/mcp-workspace"

if [[ $# -ne 1 ]]; then
	echo "Usage: $0 /path/to/host/workspace" >&2
	exit 1
fi

# Resolve workspace path to absolute
WORKSPACE_DIR_INPUT="$1"
if command -v realpath >/dev/null 2>&1; then
	WORKSPACE_DIR="$(realpath "$WORKSPACE_DIR_INPUT")"
elif command -v readlink >/dev/null 2>&1; then
	WORKSPACE_DIR="$(readlink -f "$WORKSPACE_DIR_INPUT")"
else
	# Fallback: cd and print pwd
	WORKSPACE_DIR="$(cd "$WORKSPACE_DIR_INPUT" && pwd)"
fi

if [[ ! -d "$WORKSPACE_DIR" ]]; then
	echo "Error: workspace directory not found: $WORKSPACE_DIR" >&2
	exit 1
fi

if [[ ! -f "$ROOTFS_IMG" ]]; then
	echo "Error: $ROOTFS_IMG not found in current directory." >&2
	exit 1
fi

echo "This will copy files from the VM ($VM_WORK_DIR) into:"
echo "  $WORKSPACE_DIR"
echo "It may overwrite existing files."
echo "A backup of the entire workspace will be created in the current directory before proceeding."
read -r -p "Proceed with overwrite and backup? [y/N]: " REPLY
REPLY=${REPLY:-N}
case "$REPLY" in
	y|Y|yes|YES)
		;;
	*)
		echo "Aborted by user."
		exit 1
		;;
esac

# Create a timestamped backup tarball of the workspace in the current directory
TS="$(date +"%Y%m%d-%H%M%S")"
WS_NAME="$(basename "$WORKSPACE_DIR")"
BACKUP_FILE="backup-${WS_NAME}-${TS}.tar.gz"
echo "[] Creating backup: ./$BACKUP_FILE"
tar -C "$(dirname "$WORKSPACE_DIR")" -czf "$BACKUP_FILE" "$WS_NAME"
echo "[] Backup created."

# Ensure cleanup on exit
cleanup() {
	if mountpoint -q "$MOUNT_DIR" 2>/dev/null; then
		sudo umount "$MOUNT_DIR" || true
	fi
	rmdir "$MOUNT_DIR" 2>/dev/null || true
}
trap cleanup EXIT

echo "[] Mounting rootfs image..."
mkdir -p "$MOUNT_DIR"
sudo mount -o loop "$ROOTFS_IMG" "$MOUNT_DIR"
SRC_DIR="$MOUNT_DIR$VM_WORK_DIR"
echo ${SRC_DIR}
if [[ ! -d "$SRC_DIR" ]]; then
	echo "[!] Warning: $VM_WORK_DIR does not exist inside the VM image; nothing to move."
	echo "[] Unmounting and truncating image back to 2GiB..."
	sudo umount "$MOUNT_DIR"; rmdir "$MOUNT_DIR"
	trap - EXIT
	echo "[] Truncating $ROOTFS_IMG to 2GiB..."
	sudo truncate -s 2G "$ROOTFS_IMG"
	echo "[] Done."
	exit 0
fi

# Copy from VM to host workspace
echo "[] Copying files from $VM_WORK_DIR -> $WORKSPACE_DIR ..."
sudo cp -a "$SRC_DIR/." "$WORKSPACE_DIR/"


# Remove files from inside the VM directory
echo "[] Clearing $VM_WORK_DIR inside VM image..."
sudo rm -rf "$SRC_DIR"
sudo mkdir -p "$SRC_DIR"

# Unmount and truncate image back to 2GiB
echo "[] Unmounting rootfs image..."
sudo umount "$MOUNT_DIR"; rmdir "$MOUNT_DIR"
trap - EXIT

# Resizing the image back to 2GiB using resize2fs and truncate
# also check if resize2fs fails, then don't truncate
echo "[] Resizing $ROOTFS_IMG back to 2GiB..."
e2fsck -f rootfs.ext4
if sudo resize2fs -M "$ROOTFS_IMG"; then
    sudo truncate -s 2G "$ROOTFS_IMG"
    echo "[] Resize complete."
else
    echo "[!] Warning: resize2fs failed, skipping truncate step."
fi

echo "[] Move complete! Backup saved at: ./$BACKUP_FILE"

