#!/usr/bin/env bash
# Run the build's own host_init_verifier over every stock vendor init script.
#
# Catches rc problems (missing user, unknown HIDL interface in an `interface`
# line, bad sockets/keycodes, ...) in seconds instead of one per build run.
# Needs a previous build that got far enough to create the passwd/property
# context intermediates and the host_init_verifier binary.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
H="$ROOT/out/host/linux-x86/bin/host_init_verifier"
P="$ROOT/out/target/product/boratf/obj/ETC"
RC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../../vendor/tcl/boratf/proprietary/vendor/etc/init"

[ -x "$H" ] || { echo "missing $H - run a build first" >&2; exit 1; }

ARGS=(
    -p "$P/passwd_system_intermediates/passwd_system"
    -p "$P/passwd_system_ext_intermediates/passwd_system_ext"
    -p "$P/passwd_vendor_intermediates/passwd_vendor"
    -p "$P/passwd_odm_intermediates/passwd_odm"
    -p "$P/passwd_product_intermediates/passwd_product"
    --property-contexts="$P/plat_property_contexts_intermediates/plat_property_contexts"
    --property-contexts="$P/system_ext_property_contexts_intermediates/system_ext_property_contexts"
    --property-contexts="$P/product_property_contexts_intermediates/product_property_contexts"
    --property-contexts="$P/vendor_property_contexts_intermediates/vendor_property_contexts"
    --property-contexts="$P/odm_property_contexts_intermediates/odm_property_contexts"
)

fails=0
total=0
while IFS= read -r f; do
    total=$((total + 1))
    if ! "$H" "${ARGS[@]}" "$f" >/tmp/host_init_verifier.out 2>&1; then
        fails=$((fails + 1))
        echo "FAIL: ${f#"$RC_DIR"/}"
        sed 's/^/    /' /tmp/host_init_verifier.out | head -6
    fi
done < <(find "$RC_DIR" -name '*.rc' | sort)

echo "checked $total files, $fails failure(s)"
[ "$fails" -eq 0 ]
