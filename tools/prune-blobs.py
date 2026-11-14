#!/usr/bin/env python3
"""Remove extracted files that are no longer in proprietary-files.txt.

extract-files.py never deletes blobs that were dropped from the list, so the
staging tree drifts. Run this after regenerating the list:

    python3 tools/gen-blobs.py
    python3 tools/prune-blobs.py
    PYTHONPATH=../../../tools/extract-utils python3 extract-files.py \
        --keep-dump /home/lucy/media/android/boratf-dump
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
VENDOR_DIR = os.path.normpath(
    os.path.join(HERE, "..", "..", "..", "..", "vendor", "tcl", "boratf")
)
PROPRIETARY = os.path.normpath(os.path.join(HERE, "..", "proprietary-files.txt"))


def main():
    keep = set()
    with open(PROPRIETARY) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            spec = line.split(";")[0]
            # "src:dst" entries are extracted under the destination name
            path = spec.split(":", 1)[1] if ":" in spec else spec
            keep.add(os.path.join("proprietary", path))

    removed = 0
    for dirpath, _, filenames in os.walk(os.path.join(VENDOR_DIR, "proprietary")):
        for name in filenames:
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, VENDOR_DIR)
            if rel not in keep:
                os.unlink(full)
                removed += 1

    print(f"kept {len(keep)} files, removed {removed} stale files")


if __name__ == "__main__":
    main()
