#!/usr/bin/env python3
"""
NVME malicious-device detector prototype.

Detects two experiment classes:
  1. Fake capacity / high-LBA data-loss or aliasing behavior.
  2. PRP/data corruption, including PRP2 shift-like attacks.

WARNING: This program writes directly to a raw block device.
Use only inside your QEMU NVMe test environment.
"""

import argparse
import hashlib
import mmap
import os
import random
import time
from typing import Iterable, Optional

BLOCK_SIZE = 512
PAGE_SIZE = 4096
DEFAULT_PRP_IO_SIZE = 8192
DEFAULT_CAPACITY_PROBES = 32
SEED = b"nvme-attack-detector-v4"


def pattern(name: bytes, size: int) -> bytes:
    out = bytearray()
    i = 0
    while len(out) < size:
        out += hashlib.sha256(SEED + name + i.to_bytes(4, "little")).digest()
        i += 1
    return bytes(out[:size])


def make_lba_block(lba: int, tag: bytes) -> bytes:
    header = f"NVME_DETECT;TAG={tag.decode()};LBA={lba};".encode()
    data = bytearray()

    i = 0
    while len(data) < BLOCK_SIZE:
        data += hashlib.sha256(
            SEED + tag + lba.to_bytes(8, "little") + i.to_bytes(4, "little")
        ).digest()
        i += 1

    block = bytearray(data[:BLOCK_SIZE])
    block[: len(header)] = header
    return bytes(block)


def make_general_prp_buffer(size: int) -> bytes:
    buf = bytearray()
    page_count = (size + PAGE_SIZE - 1) // PAGE_SIZE

    for page_idx in range(page_count):
        page = bytearray(pattern(f"PAGE_{page_idx}".encode(), PAGE_SIZE))

        magic = f"PAGE_{page_idx}_START_MAGIC".encode()
        page[: len(magic)] = magic

        mid = PAGE_SIZE // 2
        mid_magic = f"PAGE_{page_idx}_MID_MAGIC".encode()
        page[mid : mid + len(mid_magic)] = mid_magic

        end_magic = f"PAGE_{page_idx}_END_MAGIC".encode()
        page[-len(end_magic) :] = end_magic

        buf += page

    return bytes(buf[:size])


def supports_odirect() -> bool:
    return hasattr(os, "O_DIRECT") and hasattr(os, "preadv") and hasattr(os, "pwritev")


def open_dev(dev: str, write: bool, direct: bool = True):
    flags = os.O_SYNC
    flags |= os.O_RDWR if write else os.O_RDONLY
    if direct and supports_odirect():
        flags |= os.O_DIRECT
    return os.open(dev, flags)


def aligned_buffer(size: int, initial: Optional[bytes] = None) -> mmap.mmap:
    """Return a page-aligned mmap buffer usable with O_DIRECT + readv/writev."""
    buf = mmap.mmap(-1, size)
    if initial is not None:
        if len(initial) != size:
            raise ValueError(f"initial buffer length {len(initial)} != requested size {size}")
        buf.write(initial)
        buf.seek(0)
    return buf


def write_at(dev: str, offset: int, data: bytes, direct: bool = True):
    if direct and supports_odirect():
        if offset % BLOCK_SIZE != 0 or len(data) % BLOCK_SIZE != 0:
            raise ValueError("O_DIRECT requires offset and length to be block aligned")
        fd = open_dev(dev, True, direct=True)
        buf = aligned_buffer(len(data), data)
        try:
            n = os.pwritev(fd, [buf], offset)
            os.fsync(fd)
            if n != len(data):
                raise RuntimeError(f"short direct write {n}/{len(data)}")
        finally:
            buf.close()
            os.close(fd)
        return

    fd = open_dev(dev, True, direct=False)
    try:
        os.lseek(fd, offset, os.SEEK_SET)
        n = os.write(fd, data)
        os.fsync(fd)
        if n != len(data):
            raise RuntimeError(f"short write {n}/{len(data)}")
    finally:
        os.close(fd)


def read_at(dev: str, offset: int, size: int, direct: bool = True) -> bytes:
    if direct and supports_odirect():
        if offset % BLOCK_SIZE != 0 or size % BLOCK_SIZE != 0:
            raise ValueError("O_DIRECT requires offset and length to be block aligned")
        fd = open_dev(dev, False, direct=True)
        buf = aligned_buffer(size)
        try:
            n = os.preadv(fd, [buf], offset)
            if n != size:
                raise RuntimeError(f"short direct read {n}/{size}")
            buf.seek(0)
            return buf.read(size)
        finally:
            buf.close()
            os.close(fd)

    fd = open_dev(dev, False, direct=False)
    try:
        os.lseek(fd, offset, os.SEEK_SET)
        data = os.read(fd, size)
        if len(data) != size:
            raise RuntimeError(f"short read {len(data)}/{size}")
        return data
    finally:
        os.close(fd)


def write_lba(dev: str, lba: int, data: bytes, direct: bool = True):
    write_at(dev, lba * BLOCK_SIZE, data, direct=direct)


def read_lba(dev: str, lba: int, direct: bool = True) -> bytes:
    return read_at(dev, lba * BLOCK_SIZE, BLOCK_SIZE, direct=direct)


def unique_sorted_lbas(values: Iterable[int], reported_end_lba: int) -> list[int]:
    return sorted(set(lba for lba in values if 0 < lba < reported_end_lba))


def build_capacity_probe_lbas(reported_size_gb: float, probe_count: int) -> list[int]:
    reported_end_lba = int(reported_size_gb * 1024**3 // BLOCK_SIZE)
    if reported_end_lba <= 8192:
        raise ValueError("reported capacity is too small for this destructive probe layout")

    fixed = [
        4096,
        8192,
        reported_end_lba // 8,
        reported_end_lba // 4,
        reported_end_lba // 2,
        (reported_end_lba * 3) // 4,
        (reported_end_lba * 7) // 8,
        reported_end_lba - 4096,
        reported_end_lba - 1024,
        reported_end_lba - 8,
    ]

    rnd = random.Random(SEED + b"capacity-probes" + str(reported_end_lba).encode())
    random_lbas = [rnd.randrange(4096, reported_end_lba - 8) for _ in range(max(0, probe_count))]
    return unique_sorted_lbas(fixed + random_lbas, reported_end_lba)


def fake_capacity_test(dev: str, reported_size_gb: float, probe_count: int, direct: bool = True) -> bool:
    print("\n=== [1] Fake Capacity / High-LBA Integrity Detection ===")

    reported_end_lba = int(reported_size_gb * 1024**3 // BLOCK_SIZE)
    test_lbas = build_capacity_probe_lbas(reported_size_gb, probe_count)

    suspicious = False
    expected_by_lba: dict[int, bytes] = {}

    print(f"[INFO] reported_size_gb={reported_size_gb}")
    print(f"[INFO] reported_end_lba={reported_end_lba}")
    print(f"[INFO] probe_lba_count={len(test_lbas)}")
    print(f"[INFO] io_mode={'O_DIRECT' if direct and supports_odirect() else 'buffered'}")
    print("[INFO] No real capacity is assumed. Detection is based on readback mismatch and LBA aliasing.")

    print("[INFO] Writing deterministic one-block patterns to sparse LBAs...")
    for lba in test_lbas:
        expected = make_lba_block(lba, b"FAKECAP")
        expected_by_lba[lba] = expected
        try:
            write_lba(dev, lba, expected, direct=direct)
            print(f"[WRITE_OK] LBA {lba}")
        except Exception as e:
            print(f"[WRITE_ERR] LBA {lba}: {e}")
            suspicious = True

    print("[INFO] Reading back all probe LBAs after all writes...")
    actual_by_lba: dict[int, bytes] = {}
    for lba in test_lbas:
        expected = expected_by_lba[lba]
        try:
            actual = read_lba(dev, lba, direct=direct)
            actual_by_lba[lba] = actual
            if actual == expected:
                print(f"[PASS] LBA {lba}: matched")
            else:
                print(f"[ALERT] LBA {lba}: mismatch")
                print(f"        Expected: {expected[:80]!r}")
                print(f"        Actual:   {actual[:80]!r}")
                suspicious = True
        except Exception as e:
            print(f"[READ_ERR] LBA {lba}: {e}")
            suspicious = True

    print("[INFO] Checking whether one probe LBA returns another probe LBA's pattern...")
    pattern_owner = {data: lba for lba, data in expected_by_lba.items()}
    for lba, actual in actual_by_lba.items():
        owner = pattern_owner.get(actual)
        if owner is not None and owner != lba:
            print(f"[ALERT] LBA aliasing detected: LBA {lba} returned pattern written to LBA {owner}")
            suspicious = True

    print(f"[RESULT] Fake capacity/high-LBA integrity: {'SUSPICIOUS' if suspicious else 'not detected'}")
    return suspicious


def hexdump_diff(expected: bytes, actual: bytes, start: int, length: int = 128):
    end = min(start + length, len(expected))
    print(f"\n--- diff window offset 0x{start:x} ~ 0x{end:x} ---")
    print(f"expected: {expected[start:end].hex()}")
    print(f"actual:   {actual[start:end].hex()}")


def infer_shift(expected: bytes, actual: bytes, max_shift: int = 2048):
    print("\n[INFO] Trying to infer possible byte-shift pattern...")

    best_shift = None
    best_score = 0
    best_direction = None

    max_shift = min(max_shift, len(expected) // 2)

    for shift in range(1, max_shift + 1):
        forward_score = sum(1 for a, b in zip(actual[:-shift], expected[shift:]) if a == b)
        backward_score = sum(1 for a, b in zip(actual[shift:], expected[:-shift]) if a == b)

        if forward_score > best_score:
            best_score = forward_score
            best_shift = shift
            best_direction = "actual_is_expected_shifted_forward"

        if backward_score > best_score:
            best_score = backward_score
            best_shift = shift
            best_direction = "actual_is_expected_shifted_backward"

    ratio = best_score / len(expected)

    if ratio > 0.80:
        print(
            f"[INFO] possible {best_direction}: "
            f"{best_shift} bytes, match_ratio={ratio:.2%}"
        )
    else:
        print(f"[INFO] no clear byte-shift pattern inferred; best_ratio={ratio:.2%}")


def prp_corruption_test(dev: str, lba: int, io_size: int, direct: bool = True) -> bool:
    print("\n=== [2] General PRP/Data Corruption Detection ===")
    print(f"[INFO] single I/O size = {io_size} bytes")
    print(f"[INFO] start_lba = {lba}")
    print(f"[INFO] byte_offset = 0x{lba * BLOCK_SIZE:x}")
    print(f"[INFO] io_mode={'O_DIRECT' if direct and supports_odirect() else 'buffered'}")

    if io_size < PAGE_SIZE * 2:
        print("[WARN] io_size smaller than 8KiB may not force PRP2 usage")

    if io_size % BLOCK_SIZE != 0:
        raise ValueError("prp_io_size must be a multiple of 512 bytes")

    expected = make_general_prp_buffer(io_size)

    try:
        print("[INFO] Writing one large buffer to force multi-page PRP usage...")
        write_at(dev, lba * BLOCK_SIZE, expected, direct=direct)

        print("[INFO] Reading back the same range from device...")
        actual = read_at(dev, lba * BLOCK_SIZE, io_size, direct=direct)

    except Exception as e:
        print(f"[PRP_IO_ERR] {e}")
        print("[RESULT] PRP/data corruption: SUSPICIOUS")
        return True

    if actual == expected:
        print("[PASS] readback exactly matched")
        print("[RESULT] PRP/data corruption: not detected")
        return False

    print("[ALERT] readback mismatch detected")
    suspicious = True

    page_count = (io_size + PAGE_SIZE - 1) // PAGE_SIZE

    for page_idx in range(page_count):
        start = page_idx * PAGE_SIZE
        end = min(start + PAGE_SIZE, io_size)

        if actual[start:end] == expected[start:end]:
            print(f"[PASS] page {page_idx}: matched")
        else:
            print(f"[ALERT] page {page_idx}: mismatched")
            hexdump_diff(expected, actual, start)

    infer_shift(expected, actual)

    print("[RESULT] PRP/data corruption: SUSPICIOUS")
    return suspicious


def main():
    parser = argparse.ArgumentParser(
        description="NVMe fake capacity + PRP/data corruption detector"
    )
    parser.add_argument("--dev", required=True, help="Target device, e.g. /dev/nvme0n1")
    parser.add_argument(
        "--test",
        choices=["capacity", "prp", "all"],
        default="all",
        help="Which detector to run: capacity, prp, or all",
    )
    parser.add_argument(
        "--reported-size-gb",
        type=float,
        help="Reported/visible NVMe namespace size in GiB. Required for --test capacity/all.",
    )
    parser.add_argument(
        "--capacity-probes",
        type=int,
        default=DEFAULT_CAPACITY_PROBES,
        help="Number of additional deterministic random LBA probes for capacity test",
    )
    parser.add_argument("--prp-lba", type=int, default=8192)
    parser.add_argument("--prp-io-size", type=int, default=DEFAULT_PRP_IO_SIZE)
    parser.add_argument(
        "--buffered-io",
        action="store_true",
        help="Use normal buffered I/O instead of O_DIRECT. Not recommended for PRP experiments.",
    )
    parser.add_argument("--yes", action="store_true")

    args = parser.parse_args()

    if args.test in ("capacity", "all") and args.reported_size_gb is None:
        parser.error("--reported-size-gb is required when --test is capacity or all")

    direct = not args.buffered_io

    print("WARNING: This program writes directly to a raw block device.")
    print("Use ONLY on your QEMU test NVMe disk.")
    print(f"Target device: {args.dev}")
    print(f"Selected test: {args.test}")
    if direct and not supports_odirect():
        print("[WARN] O_DIRECT is not available in this Python/OS environment; falling back to buffered I/O")

    if not args.yes:
        confirm = input("Type YES to continue: ")
        if confirm != "YES":
            print("Aborted.")
            return

    start = time.time()
    fake_result: Optional[bool] = None
    prp_result: Optional[bool] = None

    if args.test in ("capacity", "all"):
        fake_result = fake_capacity_test(
            args.dev,
            args.reported_size_gb,
            args.capacity_probes,
            direct=direct,
        )

    if args.test in ("prp", "all"):
        prp_result = prp_corruption_test(
            args.dev,
            args.prp_lba,
            args.prp_io_size,
            direct=direct,
        )

    print("\n=== Final Summary ===")
    if fake_result is not None:
        print(f"Fake capacity/high-LBA integrity: {'SUSPICIOUS' if fake_result else 'not detected'}")
    else:
        print("Fake capacity/high-LBA integrity: skipped")

    if prp_result is not None:
        print(f"PRP/data corruption:             {'SUSPICIOUS' if prp_result else 'not detected'}")
    else:
        print("PRP/data corruption:             skipped")

    print(f"Elapsed: {time.time() - start:.2f}s")


if __name__ == "__main__":
    main()

