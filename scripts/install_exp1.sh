#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QEMU_VERSION="stable-8.2"
INSTALL_DIR="$HOME/qemu-nvme-exp1"

sudo apt update
sudo apt install -y \
  git build-essential ninja-build pkg-config \
  libglib2.0-dev libpixman-1-dev zlib1g-dev \
  python3 python3-pip

git clone https://github.com/qemu/qemu.git "$INSTALL_DIR"
cd "$INSTALL_DIR"

git checkout "$QEMU_VERSION"


git apply "$REPO_DIR/patches/exp1_fake_capacity_FS.diff"

mkdir -p build
cd build

../configure --target-list=aarch64-softmmu
make -j"$(nproc)"

echo "[OK] Patched QEMU installed:"
echo "$INSTALL_DIR/build/qemu-system-aarch64"
