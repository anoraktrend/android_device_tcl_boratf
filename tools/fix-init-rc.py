#!/usr/bin/env python3
"""Make the stock vendor init scripts acceptable to modern init.

Two legacy patterns are fixed:

1. services without a `user` line (modern host_init_verifier rejects the
   implicit-root default);
2. `interface` lines naming HIDL interfaces that this build does not define
   (vendor.mediatek.hardware.dmc/apmonitor/... blobs, not built from source).
   The lines are verification metadata only - services still register with
   hwservicemanager at runtime.

Idempotent: run it after every extract-files.py run.

    python3 tools/fix-init-rc.py
"""
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
RC_DIR = os.path.normpath(
    os.path.join(HERE, "..", "..", "..", "..", "vendor", "tcl", "boratf",
                 "proprietary", "vendor", "etc", "init")
)
USER_LINE = "    user root\n"


def fix_file(path: str) -> int:
    with open(path, errors="replace") as f:
        lines = f.readlines()

    out = []
    fixed = 0
    stripped = 0
    i = 0
    while i < len(lines):
        line = lines[i]
        m = re.match(r"^service\s+(\S+)\s+\S", line)
        if not m:
            # drop HIDL interface declarations; unknown ones fail verification
            if re.match(r"^\s+interface\s+vendor\.", line):
                stripped += 1
                i += 1
                continue
            out.append(line)
            i += 1
            continue

        # copy the (possibly backslash-continued) service command
        cmd_end = i
        while cmd_end < len(lines) - 1 and lines[cmd_end].rstrip().endswith("\\"):
            cmd_end += 1
        out.extend(lines[i:cmd_end + 1])

        # scan the service block for an explicit user; blocks end at the next
        # top-level keyword
        j = cmd_end + 1
        has_user = False
        while j < len(lines):
            l = lines[j]
            if re.match(r"^(service|on|import)\s", l):
                break
            if re.match(r"^\s+user\s", l):
                has_user = True
            j += 1

        if not has_user:
            out.append(USER_LINE)
            fixed += 1
        i = cmd_end + 1

    if fixed or stripped:
        with open(path, "w") as f:
            f.writelines(out)
    return fixed, stripped


def main():
    total_fixed = 0
    total_stripped = 0
    for root, _, files in os.walk(RC_DIR):
        for name in files:
            if not name.endswith(".rc"):
                continue
            path = os.path.join(root, name)
            fixed, stripped = fix_file(path)
            if fixed or stripped:
                rel = os.path.relpath(path, RC_DIR)
                print(f"  {rel}: +user root ({fixed}), -interface ({stripped})")
                total_fixed += fixed
                total_stripped += stripped
    print(f"patched {total_fixed} services, stripped {total_stripped} interface lines")


if __name__ == "__main__":
    main()
