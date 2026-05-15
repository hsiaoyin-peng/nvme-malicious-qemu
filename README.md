# Malicious NVMe Device Experiments on QEMU

This project provides a reproducible QEMU-based environment for evaluating how a Linux guest reacts to malicious NVMe device behavior. The experiments modify QEMU's emulated NVMe controller rather than the guest Linux kernel.

## Experiments

This repository includes two QEMU NVMe experiments:

| Experiment | Description | Patch |
|---|---|---|
| Experiment 1 | Fake capacity NVMe device | `patches/exp1_fake_capacity_FS.diff` |
| Experiment 2 | PRP write address shift | `patches/exp2_prp_write.diff` |

Both patches are applied to QEMU `stable-8.2`.

## Environment

Host environment:

- Host OS: Ubuntu 22.04
- Host CPU: ARM architecture
- QEMU version: stable-8.2
- Guest OS: Alpine Linux Standard 3.23.3 aarch64
- Guest CPU: 2 cores
- Guest memory: 2 GB
- Guest system disk: 8 GB
- NVMe test image: 1 GB
- Guest tools: `nvme-cli`, `fio`, `python3`

## Repository Structure

```text
nvme-malicious-qemu/
├── README.md
├── patches/
│   └── exp_all.diff
├── scripts/
│   ├── install_qemu.sh
│   ├── prepare_alpine.sh
│   ├── run_alpine_install.sh   # Use ISO to boot in the first time and install Alpine to alpine.qcow2
│   ├── run_alpine_disk.sh      # After installing Alpine to alpine.qcow2, use alpine.qcow2 to boot
│   └── guest_setup.sh
├── guest-tools/
│   ├── nvme_attack_detector.py
│   ├── auto_detection.sh
│   └── README.md
├── images/
│   └── README.md
├── docs/
│   ├── experiment-1-fake-capacity.md
│   └── experiment-2-prp-shift.md
└── results/
    ├── exp1/
    └── exp2/
```
## Install patched QEMU

**Clone the repository**
```bash
git clone [https://github.com](https://github.com/hsiaoyin-peng/nvme-malicious-qemu.git)
cd nvme-malicious-qemu
```
**Install patched QEMU**
```bash
chmod +x scripts/install_qemu.sh
./scripts/install_qemu.sh
```
This script downloads QEMU stable-8.2, applies the NVMe experiment patches, and builds the patched QEMU binary.
The patched QEMU binary will be located at:
```bash
~/qemu-nvme-malicious/build/qemu-system-aarch64
```
## Alpine environment
### Prepare Alpine Linux and disk images
```bash
chmod +x scripts/prepare_alpine.sh
./scripts/prepare_alpine.sh
```
This script downloads the Alpine Linux aarch64 ISO and creates:
```bash
images/alpine.qcow2
images/nvme.img
```
Boot VM and install guest tools

### Booting Alpine Linux
This project provides two QEMU boot scripts.

**First boot: install Alpine from ISO**

Use this script only for the first boot. It boots from the Alpine ISO and installs Alpine Linux into `images/alpine.qcow2`.
```bash
./scripts/run_alpine_install.sh
```
Inside Alpine, login as root and run:
```bash
setup-alpine
```
When asked for the installation disk, select:
```bash
vda
```
Use `sys` mode to install Alpine to the virtual disk and choose to erase disk.
After installation finishes, shut down the VM:
```bash
poweroff
```
**Normal boot: boot from installed disk**

After Alpine has been installed into images/alpine.qcow2, use:
```bash
./scripts/run_alpine_disk.sh
```
The guest should contain two main block devices:
```bash
/dev/vda       Alpine system disk
/dev/nvme0n1   NVMe test device
```
Check the network is connected. If not, setup the dhcp manually.
```bash
# Make sure you get the ip address and nic
ipaddr
# If not, setup dhcp
ip link set eth0 up
udhcpc -i eth0
# Check the IP address again
ipaddr
````
Download the guest tool in Alpine
```bash
wget https://raw.githubusercontent.com/hsiaoyin-peng/nvme-malicious-qemu/main/scripts/guest_setup.sh
chmod +x guest_setup.sh
./guest_setup.sh
```
Turn the power off and use the run_alpine_disk to run alpine again.
## Guest-side Detection Tools

This repository also includes guest-side detection scripts under:

```text
guest-tools/
├── nvme_attack_detector.py
└── auto_detection.sh
```
These scripts should be executed inside the Alpine Linux guest VM.
Check the NVMe Test Device
```bash
nvme list
lsblk
dmesg | grep -i nvme
```
The expected NVMe test device is: `/dev/nvme0n1`

**Download the Detection Tools inside Alpine**

Option 1: clone the full repository:
```bash
git clone https://github.com/hsiaoyin-peng/nvme-malicious-qemu.git
cd nvme-malicious-qemu/guest-tools
chmod +x auto_detection.sh
```
Option 2: download only the guest tools:
```bash
mkdir -p ~/nvme-tools
cd ~/nvme-tools

wget https://raw.githubusercontent.com/hsiaoyin-peng/nvme-malicious-qemu/main/guest-tools/nvme_attack_detector.py
wget https://raw.githubusercontent.com/hsiaoyin-peng/nvme-malicious-qemu/main/guest-tools/auto_detection.sh

chmod +x auto_detection.sh
```
**Usage**

Ref: Go to guest-tools/README.md

## Notes
This project is intended for controlled security research and educational experiments. The modified QEMU binary should only be used in an isolated VM environment.
