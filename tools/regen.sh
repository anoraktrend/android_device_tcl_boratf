#!/usr/bin/env bash
# Regenerate proprietary-files.txt and the extracted vendor tree.
#
# Order matters:
#   1. gen-blobs.py    builds the list from the stock listing + drop-blobs.txt
#   2. prune-blobs.py  removes extracted files no longer in the list
#      (extract-files.py also cleans up, this is belt and braces)
#   3. extract-files.py copies the blobs into vendor/tcl/boratf
#   4. fix-init-rc.py  adds the `user root` the stock rc files lack
#
# The stock images must be mounted:
#   /mnt/vendor  /mnt/product  /mnt/odm-tmp
# and the dump dir (symlinks to them) at:
#   /home/lucy/media/android/boratf-dump
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE="$HERE/.."
DUMP="${BORATF_DUMP:-/home/lucy/media/android/boratf-dump}"

cd "$DEVICE"

echo "== generating proprietary-files.txt"
python3 tools/gen-blobs.py

echo "== pruning stale extracted files"
python3 tools/prune-blobs.py

echo "== extracting blobs (dump: $DUMP)"
PYTHONPATH=../../../tools/extract-utils python3 extract-files.py --keep-dump "$DUMP"

echo "== patching init rc files"
python3 tools/fix-init-rc.py

echo "== done"
