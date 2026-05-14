#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_DIR="$REPO_DIR/images"

mkdir -p "$IMAGE_DIR"

ALPINE_VERSION="3.23.3"
ALPINE_ISO="alpine-standard-${ALPINE_VERSION}-aarch64.iso"
ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/aarch64/${ALPINE_ISO}"

SYSTEM_DISK="$IMAGE_DIR/alpine.qcow2"
NVME_IMG="$IMAGE_DIR/nvme.img"

cd "$IMAGE_DIR"

if [ ! -f "$ALPINE_ISO" ]; then
  echo "[INFO] Downloading Alpine ISO..."
  wget "$ALPINE_URL"
else
  echo "[OK] Alpine ISO already exists."
fi

if [ ! -f "$SYSTEM_DISK" ]; then
  echo "[INFO] Creating Alpine system disk: $SYSTEM_DISK"
  qemu-img create -f qcow2 "$SYSTEM_DISK" 8G
else
  echo "[OK] Alpine system disk already exists."
fi

if [ ! -f "$NVME_IMG" ]; then
  echo "[INFO] Creating NVMe test image: $NVME_IMG"
  qemu-img create -f raw "$NVME_IMG" 1G
else
  echo "[OK] NVMe test image already exists."
fi

echo
echo "[OK] Alpine environment prepared:"
echo "ISO:         $IMAGE_DIR/$ALPINE_ISO"
echo "System disk: $SYSTEM_DISK"
echo "NVMe image:  $NVME_IMG"
