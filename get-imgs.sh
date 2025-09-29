#!/usr/bin/env bash
set -euo pipefail

# Variables
REPO_URL="https://github.com/firecracker-microvm/firecracker"
MOUNT_DIR="mnt"
ROOTFS_IMG="rootfs.ext4"
KERNEL_IMG="vmlinux.bin"
KERNEL_URL="https://s3.amazonaws.com/spec.ccfc.min/img/hello/kernel/hello-vmlinux.bin"
ROOTFS_URL="https://s3.amazonaws.com/spec.ccfc.min/firecracker-ci/v1.12/x86_64/ubuntu-24.04.squashfs"
INIT_SCRIPT="initialize.sh"
SERVER_CONFIG="servers.json"

echo "[] Getting RootFS image"
wget -O ubuntu.squashfs $ROOTFS_URL

# Extract 
echo "[] Extracting image"
unsquashfs -d squashfs-root ubuntu.squashfs
#Create ext4 image
echo "[] Creating blank img"
dd if=/dev/zero of=$ROOTFS_IMG status=progress bs=1M count=2048
echo "[] Formating to ext4"
mkfs.ext4 -F $ROOTFS_IMG
#Mount 
echo "[] Mounting img"
mkdir -p $MOUNT_DIR
sudo mount -o loop $ROOTFS_IMG $MOUNT_DIR
#Copy 
echo "[] Copying"
sudo cp -a squashfs-root/* $MOUNT_DIR

echo "[] Copying initialize.sh"
sudo cp "$INIT_SCRIPT" "$MOUNT_DIR/root/"
sudo chmod +x "$MOUNT_DIR/root/$INIT_SCRIPT"
echo "[] Copying servers.json"
sudo cp "$SERVER_CONFIG" "$MOUNT_DIR/root/"
echo "bash /root/initialize.sh" | sudo tee -a $MOUNT_DIR/root/.bashrc

echo "[] Fetching kernel from aws CI"
curl -fsSL -o $KERNEL_IMG $KERNEL_URL
echo "[] Cleaning up."
sudo umount $MOUNT_DIR
rmdir $MOUNT_DIR
sudo rm -rf squashfs-root
rm -rf ubuntu*.squashfs

echo "Done! Rootfs: $ROOTFS_IMG"
echo "Kernel: $KERNEL_IMG"
