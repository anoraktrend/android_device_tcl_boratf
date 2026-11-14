#!/usr/bin/env python3
"""Generate proprietary-files.txt for tcl/boratf from the stock vendor listing."""
import fnmatch
import os
import re
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
STOCK = os.environ.get(
    "BORATF_STOCK_PATHS", os.path.join(HERE, "stock", "stock-vendor-paths.txt")
)
LINKS = os.environ.get(
    "BORATF_STOCK_LINKS", os.path.join(HERE, "stock", "stock-symlinks-full.txt")
)
DROP_FILE = os.path.join(HERE, "drop-blobs.txt")
OUT = os.path.normpath(os.path.join(HERE, "..", "proprietary-files.txt"))

# Exact paths to drop (rebuilt by the ROM or not wanted)
DROP_EXACT = {
    # rebuilt HAL services / daemons
    "vendor/bin/hw/android.hardware.audio.service.mediatek",
    "vendor/bin/hw/android.hardware.bluetooth@1.1-service-mediatek",
    "vendor/bin/hw/android.hardware.drm@1.4-service.clearkey",
    "vendor/bin/hw/android.hardware.gatekeeper@1.0-service",
    "vendor/bin/hw/android.hardware.graphics.composer@2.1-service",
    "vendor/bin/hw/android.hardware.health@2.1-service",
    "vendor/bin/hw/android.hardware.memtrack@1.0-service",
    "vendor/bin/hw/android.hardware.sensors@2.0-service.multihal-mediatek",
    "vendor/bin/hw/android.hardware.thermal@2.0-service.mtk",
    "vendor/bin/hw/android.hardware.usb@1.2-service-mediatekv2",
    "vendor/bin/hw/android.hardware.vibrator-service.mediatek",
    "vendor/bin/hw/android.hardware.lights-service.mediatek",
    "vendor/bin/hw/vendor.mediatek.hardware.mtkpower@1.0-service",
    # their rc files
    "vendor/etc/init/android.hardware.audio.service.mediatek.rc",
    "vendor/etc/init/android.hardware.bluetooth@1.1-service-mediatek.rc",
    "vendor/etc/init/android.hardware.drm@1.4-service.clearkey.rc",
    "vendor/etc/init/android.hardware.gatekeeper@1.0-service.rc",
    "vendor/etc/init/android.hardware.graphics.composer@2.1-service.rc",
    "vendor/etc/init/android.hardware.health@2.1-service.rc",
    "vendor/etc/init/android.hardware.memtrack@1.0-service.rc",
    "vendor/etc/init/android.hardware.sensors@2.0-service.multihal-mediatek.rc",
    "vendor/etc/init/android.hardware.thermal@2.0-service.mtk.rc",
    "vendor/etc/init/android.hardware.usb@1.2-service-mediatekv2.rc",
    "vendor/etc/init/lights-mtk-default.rc",
    "vendor/etc/init/vibrator-mtk-default.rc",
    "vendor/etc/init/vendor.mediatek.hardware.mtkpower@1.0-service.rc",
    # their vintf fragments
    "vendor/etc/vintf/manifest/lights-mtk-default.xml",
    "vendor/etc/vintf/manifest/vibrator-mtk-default.xml",
    "vendor/etc/vintf/manifest/power-default.xml",
    "vendor/etc/vintf/manifest/android.hardware.usb@1.2-service-mediatekv2.xml",
    "vendor/etc/vintf/manifest/android.hardware.health@2.1.xml",
    "vendor/etc/vintf/manifest/manifest_android.hardware.drm@1.4-service.clearkey.xml",
    # device manifest comes from the device tree
    "vendor/etc/vintf/manifest.xml",
    # platform provides the vendor compatibility matrix (system/libhidl/vintfdata)
    "vendor/etc/vintf/compatibility_matrix.xml",
    # build-provided HAL impls
    "vendor/lib/hw/android.hardware.gatekeeper@1.0-impl.so",
    "vendor/lib64/hw/android.hardware.gatekeeper@1.0-impl.so",
    "vendor/lib/hw/android.hardware.health@2.0-impl-2.1.so",
    "vendor/lib64/hw/android.hardware.health@2.0-impl-2.1.so",
    "vendor/lib/hw/android.hardware.memtrack@1.0-impl.so",
    "vendor/lib64/hw/android.hardware.memtrack@1.0-impl.so",
    "vendor/lib/hw/power.default.so",
    "vendor/lib64/hw/power.default.so",
    "vendor/lib/hw/vibrator.default.so",
    "vendor/lib64/hw/vibrator.default.so",
    "vendor/lib/hw/lights.mt6765.so",
    "vendor/lib64/hw/lights.mt6765.so",
    "vendor/lib64/android.hardware.power-service-mediatek.so",
    "vendor/lib64/android.hardware.power@1.0.so",
    "vendor/lib64/android.hardware.power@1.1.so",
    "vendor/lib64/android.hardware.power@1.2.so",
    # stock recovery / OTA leftovers
    "vendor/bin/applypatch",
    "vendor/bin/install-recovery.sh",
    "vendor/recovery-from-boot.p",
    # stock build.prop replaced by the build
    "vendor/build.prop",
    # stale MTK power iface libs (service replaced)
    "vendor/lib/vendor.mediatek.hardware.mtkpower@1.0.so",
    "vendor/lib/vendor.mediatek.hardware.mtkpower@1.1.so",
    "vendor/lib64/vendor.mediatek.hardware.mtkpower@1.0.so",
    "vendor/lib64/vendor.mediatek.hardware.mtkpower@1.1.so",
    # MTK factory / meta mode init scripts: not used by a normal ROM boot and
    # they define duplicate ueventd/adbd services that modern init rejects.
    "vendor/etc/init/hw/factory_init.rc",
    "vendor/etc/init/hw/factory_init.connectivity.rc",
    "vendor/etc/init/hw/factory_init.connectivity.common.rc",
    "vendor/etc/init/hw/factory_init.project.rc",
    "vendor/etc/init/hw/meta_init.rc",
    "vendor/etc/init/hw/meta_init.vendor.rc",
    "vendor/etc/init/hw/meta_init.modem.rc",
    "vendor/etc/init/hw/meta_init.connectivity.rc",
    "vendor/etc/init/hw/meta_init.connectivity.common.rc",
    "vendor/etc/init/hw/meta_init.project.rc",
    # Megvii / Face++ blobs (prohibited in LineageOS; face unlock via TCT
    # HAL will not work without them)
    "vendor/lib/libMegviiUnlock.so",
    "vendor/lib64/libMegviiUnlock.so",
    "vendor/lib/libmegface.so",
    "vendor/lib64/libmegface.so",
    "vendor/etc/megvii_model_file",
}

DROP_PREFIX = [
    "vendor/app/",
    "vendor/overlay/",
    "vendor/lib/modules/",
    "vendor/etc/selinux/",
    "vendor/vendor_dlkm/",
    "vendor/odm_dlkm/",
    "vendor/lost+found",
]

# symlinks that we recreate explicitly (map real file -> links)
EXTRA_LINKS = {}

# Stock files that the platform ships under the same name; ours is installed
# under a different name instead (map: stock path -> install path).
RENAMES = {
    # frameworks/opt/net/wifi/libwifi_hal now provides /vendor/lib64/libwifi-hal.so
    # (the legacy wifi_hal dispatcher used by the AIDL Wi-Fi HAL). The stock
    # MTK library of that name is the actual driver interface
    # (init_wifi_vendor_hal_func_table); the LineageOS MTK wrapper
    # (hardware/mediatek/wlan/libwifi-hal-wrapper) loads it as
    # "libwifi-hal-mtk.so" through /vendor/etc/wifi/vendor_hals.
    "vendor/lib64/libwifi-hal.so": "vendor/lib64/libwifi-hal-mtk.so",
}


def drop(p):
    if p in DROP_EXACT:
        return True
    return any(p.startswith(pref) for pref in DROP_PREFIX)


def load_platform_drops():
    """Paths the platform itself installs to /vendor (see drop-blobs.txt)."""
    dropped = set()
    if os.path.exists(DROP_FILE):
        with open(DROP_FILE) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    dropped.add(line)
    return dropped


def main():
    platform_drops = load_platform_drops()

    with open(STOCK) as f:
        paths = [l.strip() for l in f if l.strip()]

    link_map = defaultdict(list)
    with open(LINKS) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            src, dst = line.split(" -> ", 1)
            link_map[src].append(dst)

    # resolve each symlink chain to its real target
    def real_target(src):
        seen = set()
        target = src
        while target in link_map and target not in seen:
            seen.add(target)
            nxt = link_map[target][0]
            if not nxt.startswith("/"):
                nxt = os.path.normpath(os.path.join(os.path.dirname(target), nxt))
            target = nxt
        return target

    # The platform's shell_and_utilities_vendor installs toybox_vendor and
    # toolbox with their own applet symlinks; do not recreate them.
    PLATFORM_SHELL = (
        "/mnt/vendor/bin/toybox_vendor",
        "/mnt/vendor/bin/toolbox",
    )

    symlinks = defaultdict(list)  # real file -> [link paths]
    for src in link_map:
        if src == "/mnt/vendor/odm":
            continue  # absolute cross-partition link, handled in device.mk
        tgt = real_target(src)
        if tgt in PLATFORM_SHELL:
            continue
        symlinks[tgt].append(src)

    kept = []
    for p in paths:
        full = "/mnt/" + p
        rename = RENAMES.get(p)
        if drop(p):
            continue
        if p in platform_drops and rename is None:
            continue
        if full in link_map:
            continue  # recreated via SYMLINK args
        kept.append(f"{p}:{rename}" if rename else p)

    # merge symlink args onto the real files
    extra = defaultdict(list)
    for tgt, links in symlinks.items():
        rel_tgt = "vendor/" + tgt[len("/mnt/vendor/"):]
        rel_links = sorted("vendor/" + l[len("/mnt/vendor/"):] for l in links)
        extra[rel_tgt].extend(rel_links)

    out_lines = []
    out_lines.append("# Blobs extracted from TCL Ion V T607DL (boratf) UHBG stock firmware")
    out_lines.append("# via extract-files.py; symlinks are recreated by the extractor.")
    out_lines.append("")

    for rel in sorted(set(kept) | set(extra)):
        line = rel
        if rel in extra:
            line += ";SYMLINK=" + ",".join(sorted(extra[rel]))
        elif rel.startswith("vendor/etc/vintf/") and rel.endswith(".xml"):
            # Plain copy rules: extract-utils would otherwise turn these into
            # prebuilt_etc_xml modules whose generic names (gnss-default.xml,
            # ...) collide with the platform's own vintf fragment modules.
            line += ";MAKE_COPY_RULE_ONLY"
        out_lines.append(line)

    out_lines.append("")
    out_lines.append("# ODM (SKU properties and single-SIM vintf manifest from stock odm)")
    out_lines.append("odm/etc/LD.prop")
    out_lines.append("odm/etc/LU.prop")
    out_lines.append(
        "odm/etc/vintf/manifest_ss.xml:odm/etc/vintf/manifest.xml;MAKE_COPY_RULE_ONLY"
    )

    with open(OUT, "w") as f:
        f.write("\n".join(out_lines) + "\n")

    print("stock files:", len(paths))
    print("listed files:", len(set(kept) | set(extra)))
    print("with symlinks:", len(extra))
    for t in sorted(extra):
        if len(extra[t]) > 6:
            print(" ", t, "->", len(extra[t]), "links")
        else:
            print(" ", t, "->", sorted(extra[t]))


if __name__ == "__main__":
    main()
