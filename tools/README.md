# Porting tools

Scripts that (re)generate this device tree's blob artifacts. All inputs are
stored in-tree under `stock/`, so nothing depends on `/tmp`.

## Regenerating the vendor tree

```sh
tools/regen.sh
```

Runs, in order: `gen-blobs.py` -> `prune-blobs.py` -> `extract-files.py`
(LineageOS extract-utils) -> `fix-init-rc.py`.

Requirements: the stock images mounted at `/mnt/vendor`, `/mnt/product`,
`/mnt/odm-tmp`, and a dump dir of symlinks to them at
`/home/lucy/media/android/boratf-dump` (override with `BORATF_DUMP`).

## Tools

| tool | purpose |
|---|---|
| `gen-blobs.py` | builds `proprietary-files.txt` from `stock/stock-vendor-paths.txt` and `stock/stock-symlinks-full.txt`, minus `drop-blobs.txt` and a few hardcoded exclusions (rebuilt HALs, stock recovery bits, Megvii blobs, factory/meta init scripts). Also emits `;SYMLINK=` groups and `;MAKE_COPY_RULE_ONLY` for the vintf fragments. |
| `prune-blobs.py` | deletes extracted files that are no longer listed (extract-files.py also cleans up). |
| `fix-init-rc.py` | makes stock init scripts acceptable to modern init: inserts `user root` where the legacy implicit default was used, and strips `interface vendor.*` HIDL declarations that this build does not define. Idempotent. |
| `check-init-rc.sh` | runs the build's own `host_init_verifier` over all 94 vendor rc files (seconds, no build needed) to catch rc problems up front. |
| `filter-conflicts.py` | recomputes `drop-blobs.txt` from a build's Soong install set (`out/soong/installs-lineage_boratf.mk`); finds files the platform also installs (Kati/fsgen duplicate-install clashes). Run after a build that got past Soong analysis, followed by `tools/regen.sh`. |
| `gen-vendor-prop.py` | regenerates `vendor.prop` from `stock/vendor-build.prop`. |
| `gen-manifest.py` | regenerates `manifest.xml` from `stock/vintf-manifest.xml` (drops rebuilt HALs and dead stock HIDL entries — HIDL Bluetooth audio, OMX, MTK HIDL Bluetooth audio — and adds audio 7.1). |

## Stock inputs (`stock/`)

- `stock-vendor-paths.txt` - 2087 vendor files (from `find /mnt/vendor -type f`)
- `stock-symlinks-full.txt` - 194 symlinks with targets
- `vendor-build.prop` - copy of the stock `/vendor/build.prop`
- `vintf-manifest.xml` - copy of the stock `/vendor/etc/vintf/manifest.xml`

Refresh them from the mounted images when the firmware changes:

```sh
sudo find /mnt/vendor -type f -printf '%p\n' | sed 's|^/mnt/vendor/|vendor/|' | sort \
    > tools/stock/stock-vendor-paths.txt
sudo find /mnt/vendor -type l -printf '%p -> %l\n' | sort \
    > tools/stock/stock-symlinks-full.txt
sudo cp /mnt/vendor/build.prop tools/stock/vendor-build.prop
sudo cp /mnt/vendor/etc/vintf/manifest.xml tools/stock/vintf-manifest.xml
```

## Build-integration notes

- The blob list is installed with raw copy rules (no Soong modules), which is
  why `BoardConfig.mk` sets `BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES` and
  `BUILD_BROKEN_VINTF_PRODUCT_COPY_FILES`.
- Anything the platform itself installs to `/vendor` must not be shipped by
  the blobs; `drop-blobs.txt` records that set (361 entries).
