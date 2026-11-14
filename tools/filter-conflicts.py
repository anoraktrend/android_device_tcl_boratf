#!/usr/bin/env python3
"""Refresh tools/drop-blobs.txt from a build's Soong install set.

A file must not be shipped by both the platform and our blob tree: it either
clashes as a module (Kati "already defined") or as an install target
("overriding commands"). This script finds every path in
proprietary-files.txt that the platform also installs to the vendor
partition, and records it in drop-blobs.txt; gen-blobs.py then leaves those
paths out of the list.

Regenerate after a build (needs out/soong/installs-<product>.mk from a run
that got past Soong analysis):

    python3 tools/filter-conflicts.py
    python3 tools/gen-blobs.py
    PYTHONPATH=../../../tools/extract-utils python3 extract-files.py \
        --keep-dump /home/lucy/media/android/boratf-dump
"""
import os
import re
import sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
ANDROID_ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
INSTALLS_PRODUCT = os.environ.get("BORATF_INSTALLS_PRODUCT", "lineage_boratf")
TARGET_DEVICE = os.environ.get("BORATF_TARGET_DEVICE", "boratf")
INSTALLS = os.environ.get(
    "BORATF_INSTALLS",
    os.path.join(ANDROID_ROOT, "out", "soong", f"installs-{INSTALLS_PRODUCT}.mk"),
)
PROPRIETARY = os.path.join(HERE, "..", "proprietary-files.txt")
DROP_FILE = os.path.join(HERE, "drop-blobs.txt")

PREFIX = f"out/target/product/{TARGET_DEVICE}/vendor/"
HEADER = """# Files the platform itself installs to the vendor partition (Soong install
# set). Our blob tree must not ship them: Kati/fsgen refuse duplicate
# installs. Generated from out/soong/installs-<product>.mk by
# tools/filter-conflicts.py; re-run it (and tools/gen-blobs.py + extract) after
# a build when the platform install set changes.
"""


def main():
    if not os.path.exists(INSTALLS):
        sys.exit(f"missing install set: {INSTALLS} (run a build first)")

    sources = defaultdict(set)

    # Soong emits two shapes into the install set:
    #   1. "<install path>: <intermediates> | <deps>"   (plain installs)
    #   2. "$(eval $(call copy-*-checked, <src>, <install path>))"  (vintf
    #      manifests / init scripts, emitted as Kati copy rules)
    checked_re = re.compile(
        r"copy-[a-z-]+-checked,\s*(\S+),\s*(" + re.escape(PREFIX) + r"[^)\s]+)"
    )
    with open(INSTALLS, errors="replace") as f:
        for line in f:
            if PREFIX not in line:
                continue
            m = checked_re.search(line)
            if m:
                rel = m.group(2)[len(PREFIX):]
                sources[rel].add(m.group(1))
                continue
            if ":" not in line:
                continue
            path, _, rest = line.partition(":")
            if not path.startswith(PREFIX):
                continue
            rel = path[len(PREFIX):]
            for tok in rest.split():
                if "/" in tok:
                    sources[rel].add(tok)

    ours = []
    with open(PROPRIETARY) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            src = line.split(";")[0].split(":")[0]
            if src.startswith("vendor/"):
                ours.append(src[len("vendor/"):])

    real = {}
    for rel in ours:
        srcs = sources.get(rel)
        if not srcs:
            continue
        non_blob = sorted(s for s in srcs if "vendor/tcl/boratf" not in s)
        if non_blob:
            real[rel] = non_blob

    # merge into the existing drop list (it may contain manual entries)
    existing = set()
    if os.path.exists(DROP_FILE):
        with open(DROP_FILE) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    existing.add(line)

    updated = existing | {"vendor/" + rel for rel in real}
    new = sorted({"vendor/" + rel for rel in real} - existing)

    with open(DROP_FILE, "w") as f:
        f.write(HEADER)
        for path in sorted(updated):
            f.write(path + "\n")

    print(f"platform install set: {len(sources)} paths")
    print(f"our blob list: {len(ours)} paths")
    print(f"conflicts found: {len(real)} (new: {len(new)})")
    for path in new:
        print("  +", path)
    print(f"drop-blobs.txt: {len(updated)} entries")


if __name__ == "__main__":
    main()
