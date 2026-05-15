#!/bin/sh
set -eu

echo "[INFO] Configuring Alpine network..."

# Detect default ethernet interface.
IFACE="$(ip -o link show | awk -F': ' '/eth[0-9]|ens[0-9]|enp/ {print $2; exit}')"

if [ -z "$IFACE" ]; then
    echo "[ERROR] No Ethernet interface found."
    echo "Check with: ip link"
    exit 1
fi

echo "[INFO] Detected network interface: $IFACE"

cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto $IFACE
iface $IFACE inet dhcp
EOF

echo "[INFO] Enabling networking service..."
rc-update add networking boot || true

echo "[INFO] Bringing interface up..."
ip link set "$IFACE" up || true

echo "[INFO] Requesting DHCP address..."
udhcpc -i "$IFACE" || true

# Add fallback DNS in case DHCP does not populate resolv.conf correctly.
if ! grep -q "nameserver" /etc/resolv.conf 2>/dev/null; then
    echo "[INFO] Writing fallback DNS..."
    cat > /etc/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF
fi

echo "[INFO] Testing network..."
if ping -c 2 8.8.8.8 >/dev/null 2>&1; then
    echo "[OK] IP connectivity works."
else
    echo "[WARN] Cannot ping 8.8.8.8. Network may still be unavailable."
fi

if ping -c 2 dl-cdn.alpinelinux.org >/dev/null 2>&1; then
    echo "[OK] DNS works."
else
    echo "[WARN] DNS test failed. Rewriting /etc/resolv.conf..."
    cat > /etc/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF
fi

echo "[INFO] Setting Alpine package repositories..."

cat > /etc/apk/repositories <<EOF
https://dl-cdn.alpinelinux.org/alpine/v3.23/main
https://dl-cdn.alpinelinux.org/alpine/v3.23/community
EOF

echo "[INFO] Updating apk index..."
apk update

echo "[INFO] Installing guest dependencies..."
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
echo "[OK] Alpine guest setup completed."
echo
echo "Check NVMe device:"
echo "  nvme list"
echo "  lsblk"
echo
echo "Download guest tools:"
echo "  git clone https://github.com/YOUR_NAME/nvme-malicious-qemu.git"
echo "  cd nvme-malicious-qemu/guest-tools"
