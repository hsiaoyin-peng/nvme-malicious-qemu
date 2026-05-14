#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_DIR="$REPO_DIR/images"

QEMU_BIN="${QEMU_BIN:-$HOME/qemu-nvme-malicious/build/qemu-system-aarch64}"

ALPINE_VERSION="3.23.3"
ALPINE_ISO="$IMAGE_DIR/alpine-standard-${ALPINE_VERSION}-aarch64.iso"
SYSTEM_DISK="$IMAGE_DIR/alpine.qcow2"
NVME_IMG="$IMAGE_DIR/nvme.img"

UEFI_FW="/usr/share/qemu-efi-aarch64/QEMU_EFI.fd"

if [ ! -x "$QEMU_BIN" ]; then
  echo "[ERROR] Patched QEMU binary not found:"
  echo "  $QEMU_BIN"
  echo
  echo "Run:"
  echo "  ./scripts/install_qemu.sh"
  exit 1
fi

if [ ! -f "$UEFI_FW" ]; then
  echo "[ERROR] AArch64 UEFI firmware not found:"
  echo "  $UEFI_FW"
  echo
  echo "Install it with:"
  echo "  sudo apt install -y qemu-efi-aarch64"
  exit 1
fi

if [ ! -f "$ALPINE_ISO" ]; then
  echo "[ERROR] Alpine ISO not found:"
  echo "  $ALPINE_ISO"
  echo
  echo "Run:"
  echo "  ./scripts/prepare_alpine.sh"
  exit 1
fi

if [ ! -f "$SYSTEM_DISK" ] || [ ! -f "$NVME_IMG" ]; then
  echo "[ERROR] Disk images are missing."
  echo
  echo "Run:"
  echo "  ./scripts/prepare_alpine.sh"
  exit 1
fi

echo "[INFO] Booting Alpine installer from ISO..."
echo "[INFO] System disk: $SYSTEM_DISK"
echo "[INFO] NVMe image:  $NVME_IMG"
echo

"$QEMU_BIN" \
  -trace enable=nvme* \
  -M virt \
  -cpu max \
  -m 2G \
  -smp 2 \
  -nographic \
  -bios "$UEFI_FW" \
  -cdrom "$ALPINE_ISO" \
  -boot d \
  -drive file="$SYSTEM_DISK",if=none,id=hd0,format=qcow2 \
  -device virtio-blk-device,drive=hd0 \
  -drive file="$NVME_IMG",if=none,id=nvm0,format=raw \
  -device nvme,id=nvme0,serial=testnvme \
  -device nvme-ns,drive=nvm0,bus=nvme0,nsid=1
