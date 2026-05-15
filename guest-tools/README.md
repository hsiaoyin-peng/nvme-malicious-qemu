# Guest-side NVMe Detection Tools

These scripts are intended to run inside the Alpine Linux guest VM.

## Files

| File | Description |
|---|---|
| `nvme_attack_detector.py` | Detects fake-capacity behavior and PRP/data corruption on `/dev/nvme0n1`. |
| `auto_detection.sh` | Repeatedly runs the capacity detector and reports timing and detection statistics. |

## Usage

### Arguments

| Arguments | Type | Value | Description |
|---|---|---|---|
| `--dev` | string | /dev/nvme0n1 | Indicate the testing nvme device |
| `--test` | string|capacity or prp or all| The testing case|
| `reported-size-gb` | int | 2 or 8 or 16...| For capacity test: the device capacity |
| `capacity-probes` | int | 32 | Fro capacity test: the number of probe data |
| `prp-lba` | int | 200000 | For PRP test: the SLBA of this testing |
| `prp-io-size` | int | 8192 | For PRP test: the data size |

Run Fake Capacity Detection:
```bash
python3 nvme_attack_detector.py \
  --dev /dev/nvme0n1 \
  --test capacity \
  --reported-size-gb 8 \
  --capacity-probes 32 \
  --yes
```
Run PRP/Data Corruption Detection
```bash
python3 nvme_attack_detector.py \
  --dev /dev/nvme0n1 \
  --test prp \
  --prp-lba 200000 \
  --prp-io-size 8192 \
  --yes
```
Run All Detection Tests
```bash
python3 nvme_attack_detector.py \
  --dev /dev/nvme0n1 \
  --test all \
  --reported-size-gb 8 \
  --capacity-probes 32 \
  --prp-lba 200000 \
  --prp-io-size 8192 \
  --yes
```
Run Automated Repeated Detection
```bash
./auto_detection.sh
```
Custom configuration:
```bash
RUN_TIMES=100 REPORT_CAPACITY_GB=8 CAPACITY_PROBES=32 ./auto_detection.sh
```

## Warning

These tools write directly to a raw NVMe block device. Use them only inside the QEMU test environment.
