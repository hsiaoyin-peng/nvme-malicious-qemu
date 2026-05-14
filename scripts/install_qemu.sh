#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QEMU_VERSION="stable-8.2"
INSTALL_DIR="$HOME/qemu-nvme-malicious"

sudo apt update
sudo apt install -y \
  git build-essential ninja-build pkg-config \
  libglib2.0-dev libpixman-1-dev zlib1g-dev \
  python3 python3-pip python3-venv \
  qemu-utils wget curl xz-utils

if [ ! -d "$INSTALL_DIR" ]; then
  git clone https://github.com/qemu/qemu.git "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"
git fetch --all
git checkout "$QEMU_VERSION"

# Clean old patch state if needed
git reset --hard
git clean -fd

git apply "$REPO_DIR/patches/exp1_fake_capacity_FS.diff"
git apply "$REPO_DIR/patches/exp2_prp_write.diff"

mkdir -p build
cd build

../configure --target-list=aarch64-softmmu
make -j"$(nproc)"

mkdir -p "$HOME/.local/bin"
ln -sf "$INSTALL_DIR/build/qemu-system-aarch64" "$HOME/.local/bin/qemu-system-aarch64-nvme-malicious"

echo "[OK] Patched QEMU installed:"
echo "$INSTALL_DIR/build/qemu-system-aarch64"
echo
echo "Optional command alias:"
echo "$HOME/.local/bin/qemu-system-aarch64-nvme-malicious"
echo
echo "If ~/.local/bin is not in PATH, run:"
echo 'export PATH="$HOME/.local/bin:$PATH"'
