#!/bin/sh
set -eu

echo "[INFO] Setting up Alpine package repositories..."

cat > /etc/apk/repositories <<EOF
https://dl-cdn.alpinelinux.org/alpine/v3.23/main
https://dl-cdn.alpinelinux.org/alpine/v3.23/community
EOF

echo "[INFO] Updating apk index..."
apk update

echo "[INFO] Installing required tools..."
apk add --no-cache \
  python3 \
  py3-pip \
  fio \
  nvme-cli \
  e2fsprogs \
  util-linux \
  lsblk \
  bash \
  coreutils \
  grep \
  sed \
  gawk \
  pciutils

echo
echo "[OK] Guest tools installed."
echo
echo "Useful commands:"
echo "  nvme list"
echo "  nvme id-ns /dev/nvme0n1"
echo "  fio --version"
echo "  python3 --version"
echo "  dmesg | grep -i nvme"
