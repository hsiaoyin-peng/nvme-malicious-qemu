#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_DIR="$REPO_DIR/images"

QEMU_BIN="${QEMU_BIN:-$HOME/qemu-nvme-malicious/build/qemu-system-aarch64}"

ALPINE_VERSION="3.23.3"
ALPINE_ISO="$IMAGE_DIR/alpine-standard-${ALPINE_VERSION}-aarch64.iso"
SYSTEM_DISK="$IMAGE_DIR/alpine.qcow2"
NVME_IMG="$IMAGE_DIR/nvme.img"

if [ ! -x "$QEMU_BIN" ]; then
  echo "[ERROR] Patched QEMU binary not found:"
  echo "$QEMU_BIN"
  echo
  echo "Run:"
  echo "./scripts/install_qemu.sh"
  exit 1
fi

if [ ! -f "$ALPINE_ISO" ] || [ ! -f "$SYSTEM_DISK" ] || [ ! -f "$NVME_IMG" ]; then
  echo "[ERROR] Alpine ISO or disk images are missing."
  echo "Run:"
  echo "./scripts/prepare_alpine.sh"
  exit 1
fi

"$QEMU_BIN" \
  -M virt \
  -cpu max \
  -m 2G \
  -smp 2 \
  -display none \
  -serial mon:stdio \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/AAVMF/AAVMF_CODE.fd \
  -cdrom "$ALPINE_ISO" \
  -drive if=virtio,file="$SYSTEM_DISK",format=qcow2 \
  -drive file="$NVME_IMG",if=none,id=nvme0,format=raw \
  -device nvme,drive=nvme0,serial=deadbeef \
  -nic user,model=virtio-net-pci
