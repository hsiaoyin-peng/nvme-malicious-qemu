#!/bin/sh
set -eu

echo "[INFO] Setting up Alpine repositories..."

cat > /etc/apk/repositories <<EOF
https://dl-cdn.alpinelinux.org/alpine/v3.23/main
https://dl-cdn.alpinelinux.org/alpine/v3.23/community
EOF

echo "[INFO] Updating apk index..."
apk update

echo "[INFO] Installing guest tools..."
apk add --no-cache \
  bash \
  python3 \
  py3-pip \
  fio \
  nvme-cli \
  e2fsprogs \
  util-linux \
  coreutils \
  grep \
  sed \
  gawk \
  bc \
  git \
  wget \
  curl \
  pciutils

echo
echo "[OK] Guest dependencies installed."
echo
echo "Next step:"
echo "  git clone https://github.com/YOUR_NAME/nvme-malicious-qemu.git"
echo "  cd nvme-malicious-qemu/guest-tools"
echo "  chmod +x auto_detection.sh"
