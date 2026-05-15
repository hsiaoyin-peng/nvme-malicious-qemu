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
├── patches/
│   ├── exp1_fake_capacity_FS.diff
│   └── exp2_prp_write.diff
├── scripts/
│   ├── install_qemu.sh
│   ├── prepare_alpine.sh
│   ├── run_alpine_install.sh   # Use ISO to boot in the first time and install Alpine to alpine.qcow2
|   ├── run_alpine_disk.sh      # After installing Alpine to alpine.qcow2, use alpine.qcow2 to boot
│   └── guest_setup.sh
├── images/
├── docs/
└── results/
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
Use `sys` mode to install Alpine to the virtual disk.
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
**Start the Alpine VM**

After Alpine boots, login as root and run:
```bash
apk update
apk add --no-cache python3 py3-pip fio nvme-cli e2fsprogs util-linux bash coreutils
```
Or copy and run:
```bash
sh scripts/guest_setup.sh
```
Required guest tools:
|Tool|Purpose|
|----------|-----------------|
| `nvme-cli`   | Inspect NVMe namespace and controller information    |
| `fio`        | Generate storage workloads                           |
| `python3`    | Run detection or validation scripts                  |
| `e2fsprogs`  | Create and check ext4 filesystems                    |
| `util-linux` | Provides tools such as `lsblk`, `mount`, and `fdisk` |

## Basic Test Commands
Inside the Alpine guest:
```bash
nvme list
nvme id-ns /dev/nvme0n1
dmesg | grep -i nvme
```
Create an ext4 filesystem:
```bash
mkfs.ext4 /dev/nvme0n1
mkdir -p /mnt/nvme
mount /dev/nvme0n1 /mnt/nvme
```
Run a basic fio test:
```bash
fio --name=nvme-test \
    --filename=/dev/nvme0n1 \
    --rw=write \
    --bs=4k \
    --size=512M \
    --direct=1
```
## Notes
This project is intended for controlled security research and educational experiments. The modified QEMU binary should only be used in an isolated VM environment.
