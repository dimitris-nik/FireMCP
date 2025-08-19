#!/usr/bin/env bash
set -euo pipefail

# Variables
REPO_URL="https://github.com/firecracker-microvm/firecracker"
MOUNT_DIR="mnt"
ROOTFS_IMG="rootfs.ext4"

git clone "$REPO_URL"
./firecracker/tools/devtool build_ci_artifacts rootfs

echo "Filesystem creation done. Now making ext4 img"
#Copy image
mv firecracker/resources/x86_64/ubuntu*.squashfs ./
# Extract 
unsquashfs -d squashfs-root ubuntu*.squashfs
#Create ext4 image
echo "Creating blank img"
dd if=/dev/zero of=$ROOTFS_IMG bs=1M count=2048
echo "Formating to ext4"
mkfs.ext4 -F $ROOTFS_IMG
#Mount 
echo "Mounting img"
mkdir -p $MOUNT_DIR
sudo mount -o loop $ROOTFS_IMG $MOUNT_DIR
#Copy 
echo "copying"
sudo cp -a squashfs-root/* $MOUNT_DIR

echo "Fetching kernel from aws CI"
curl -fsSL -o vmlinux.bin https://s3.amazonaws.com/spec.ccfc.min/img/hello/kernel/hello-vmlinux.bin
echo "Cleaning up."
sudo umount $MOUNT_DIR
rmdir $MOUNT_DIR
sudo rm -rf squashfs-root
rm -rf ubuntu*.squashfs

echo "Done! Rootfs created: $ROOTFS_IMG"

