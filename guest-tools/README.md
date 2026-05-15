# Guest-side NVMe Detection Tools

These scripts are intended to run inside the Alpine Linux guest VM.

## Files

| File | Description |
|---|---|
| `nvme_attack_detector.py` | Detects fake-capacity behavior and PRP/data corruption on `/dev/nvme0n1`. |
| `auto_detection.sh` | Repeatedly runs the capacity detector and reports timing and detection statistics. |

## Warning

These tools write directly to a raw NVMe block device. Use them only inside the QEMU test environment.
