# Hybrid HAL configuration — open-source AIDL services on the stock MTK vendor blobs

Scratch clone of `device/tcl/boratf` + `vendor/tcl/boratf`, taken from
`/home/lucy/media/android/lineage-24` (2026-11-13, after the successful build
`2026-11-13T04:31:45 BUILD EXIT: 0`).

* clone root: `/tmp/opencode/boratf-aidl-scratch`
* device tree: `device/tcl/boratf` (same relative path as in the AOSP tree)
* blob tree: `vendor/tcl/boratf`
* sync back: `../sync-back.sh` (rsyncs both trees into the live checkout)

All facts below were read from this tree (FCM files, Soong modules, the staged
product dir `out/target/product/boratf`, and the stock dump at
`/home/lucy/media/android/boratf-dump` → `/mnt/vendor`).

---

## 1. What the platform actually requires

The device manifest is built at **target-level 7** (`<manifest version="9.0"
type="device" target-level="7">` in the staged `vendor/etc/vintf/manifest.xml`,
and `checkvintf` reports `kernel FCM version = 7`), so the governing matrix is
`hardware/interfaces/compatibility_matrices/compatibility_matrix.7.xml`.
The date-named matrices (`202404 … 202704`) contain **no HIDL entries at all**
and are not binding for a level-7 device.

Relevant level-7 entries:

| HAL | Level-7 matrix entry | Notes |
|---|---|---|
| `android.hardware.wifi` | **HIDL 1.3-6** `IWifi` | no AIDL entry at level 7 |
| `android.hardware.wifi.supplicant` | **AIDL** `ISupplicant` (v1) | HIDL 1.x is *not* listed |
| `android.hardware.wifi.hostapd` | **AIDL** `IHostapd` v1 | HIDL 1.x is *not* listed |
| `android.hardware.bluetooth` | **HIDL 1.0-1** `IBluetoothHci` | |
| `android.hardware.bluetooth.audio` | **AIDL** `IBluetoothAudioProviderFactory` v2 | |
| `android.hardware.health` | **AIDL** `IHealth` v1 | |
| `android.hardware.gnss` | **HIDL 2.0-1** *and* **AIDL 1-2** | both declared |
| `android.hardware.audio` | **HIDL 6.0, 7.0-1** `IDevicesFactory` | |
| `android.hardware.audio.effect` | **HIDL 6.0, 7.0** | |

Two runtime facts that matter more than the matrix:

1. `packages/modules/Wifi` has **no HIDL client** any more (no `HidlManager`,
   no `android.hardware.wifi@1.x` usage in `service/java`) and the AIDL Wi-Fi
   HAL is `updatable-via-apex="true"` in the current matrices → the framework
   only ever talks to the **AIDL** Wi-Fi HAL.
2. There is no AIDL Wi-Fi HAL *service* in the `com.android.wifi` APEX in this
   build (`out/target/product/boratf/apex/com.android.wifi/bin` contains only
   `wpa_supplicant_mainline`) — `android.hardware.wifi-service` installs to
   `/vendor` and therefore has to be requested by the device tree.

## 2. Hybrid matrix (verified state)

| Subsystem | Userspace service (this build) | Format | Drives | Status |
|---|---|---|---|---|
| Health | `android.hardware.health-service.mediatek` (`hardware/mediatek/aidl/health`, declares `IHealth` **v5**) | AIDL | kernel `/sys/class/power_supply` | already correct |
| Wi-Fi HAL | `android.hardware.wifi-service` (`hardware/interfaces/wifi/aidl/default`, `IWifi` v4) | AIDL | `libwifi-hal-wrapper.so` → `libwifi-hal-mtk.so` (= stock MTK legacy HAL) → `wmt_drv.ko` | **added by this change** |
| supplicant | `wpa_supplicant` (`external/wpa_supplicant_8`, `ISupplicant` **v5**) | AIDL | nl80211 + stock `/vendor/etc/wifi/*.conf` | **added by this change** |
| hostapd | `hostapd` (`external/wpa_supplicant_8`, `IHostapd` v3) | AIDL | nl80211 (`/dev/wmtWifi`) | **added by this change** |
| Wi-Fi (legacy) | `android.hardware.wifi@1.0-service-lazy` (stock blob, HIDL 1.5) | HIDL | same driver | kept, inert: satisfies the level-7 HIDL entry, never called by the framework |
| Bluetooth | `android.hardware.bluetooth-service.mediatek` (`hardware/mediatek/aidl/bluetooth`) | AIDL | `libbt-vendor.so` + `/dev/stpbt` | already correct (AOSP's `bluetooth-service.default` would be equivalent) |
| Audio | `android.hardware.audio.service.mediatek` (`hardware/mediatek/hidl/audio`, HIDL 7.1 + AIDL BT audio factory) | HIDL | `audio.primary.mt6765.so`, `vendor.mediatek.hardware.audio@7.1` | already correct (level 7 allows HIDL 7.1; there is no AIDL wrapper for a HIDL-7 vendor blob) |
| GNSS | `android.hardware.gnss-service.mediatek` (stock blob, HIDL 2.1) + `mnld` | HIDL | `/dev/stpgps`, MTK IPC | already correct |

`gnss-default.xml` (declares AIDL `android.hardware.gnss.IGnss/default`) and
`gnss@2.1-service.xml` (HIDL 2.1) are **both stock vendor files** — level 7
lists both interfaces, which is why the tree satisfies the check. No
`framework_compatibility_matrix.xml` entry is needed for GNSS.

## 3. Changes in this clone

### 3.1 `device.mk` — AIDL Wi-Fi stack

```make
PRODUCT_PACKAGES += \
    android.hardware.wifi-service \
    hostapd \
    libwifi-hal-wrapper \
    wlan_assistant \
    wpa_supplicant

$(call soong_config_set,wpa_supplicant_8,wifi_hidl_unified_supplicant_service_rc_entry,true)
$(call soong_config_set,mediatek_wifi_hal,use_pre_u_qpr2_struct,true)
$(call soong_config_set,mediatek_wifi_hal,use_pre_baklava_qpr0_struct,true)
```

Why each piece:

* `android.hardware.wifi-service` — the AIDL HAL. It reads
  `/vendor/etc/wifi/vendor_hals/*.xml` (`wifi_legacy_hal_factory.cpp`,
  `kVendorHalsDescPath`) and `dlopen`s the library named there, then calls
  `init_wifi_vendor_hal_func_table()`. `libwifi-hal.so` itself is provided by
  the platform (`frameworks/opt/net/wifi/libwifi_hal`).
* `libwifi-hal-wrapper` + its XML (`hardware/mediatek/wlan/libwifi-hal-wrapper`)
  — installs `/vendor/etc/wifi/vendor_hals/libwifi-hal-wrapper.xml` pointing at
  `/vendor/lib64/libwifi-hal-wrapper.so`, which `dlopen`s
  **`libwifi-hal-mtk.so`** and translates the *legacy* function table (the
  Android 13 struct layout) into the current one.
* the two `mediatek_wifi_hal` Soong config values — select the pre-Android-14
  (U QPR2) struct layout. This vendor library was built for Android 13.
* `wpa_supplicant` / `hostapd` — the AOSP AIDL implementations. The stock
  binaries are **HIDL 1.4 / 1.3** services (`/mnt/vendor/etc/vintf/manifest/
  android.hardware.wifi.{supplicant,hostapd}.xml`, and the stock rc declares
  `interface android.hardware.wifi.supplicant@1.x::ISupplicant`), and level 7
  only lists the AIDL interfaces.
* `wpa_supplicant_8.wifi_hidl_unified_supplicant_service_rc_entry=true` —
  without it the module installs **no** `.rc` (the supplicant would never
  start), because the knob exists to let the platform own the vendor-style rc
  name. The stock rc is dropped (see 3.3).
* `wlan_assistant` — MTK helper; the stock binary was already dropped from the
  blob list, so the source-built one from `hardware/mediatek/wlan` is needed.

### 3.2 `Android.bp` — declare the `mediatek_wifi_hal` Soong config namespace

`libwifi-hal-wrapper` uses `select(soong_config_variable("mediatek_wifi_hal",
…))`, but no module in this tree declared those variables. The clone adds a
`soong_config_module_type` block for them so the values set in `device.mk`
take effect instead of silently falling back to the default (post-U) layout.

### 3.3 `tools/gen-blobs.py`, `tools/drop-blobs.txt`, `proprietary-files.txt`

* `gen-blobs.py` gained `RENAMES`:

  ```python
  RENAMES = {"vendor/lib64/libwifi-hal.so": "vendor/lib64/libwifi-hal-mtk.so"}
  ```

  The stock `libwifi-hal.so` **is** the MTK legacy Wi-Fi HAL (it exports
  `init_wifi_vendor_hal_func_table`, `wifi_initialize`, `wifi_get_ifaces`, …
  — 180 functions), but that path now belongs to the platform, so it is
  installed under the name the wrapper loads.
* `proprietary-files.txt` regenerated: `-vendor/etc/init/
  android.hardware.wifi.supplicant-service.rc`,
  `+vendor/lib64/libwifi-hal.so:vendor/lib64/libwifi-hal-mtk.so`
  (only those two lines changed).
* `drop-blobs.txt` keeps the supplicant rc out of the blob tree (the platform's
  AIDL rc now takes that path). The `android.hardware.wifi.supplicant.xml` /
  `android.hardware.wifi.hostapd.xml` fragments and `libwifi-hal.so` were
  already dropped there.
* Because the clone was not re-extracted, `vendor/tcl/boratf/boratf-vendor.mk`
  has the corresponding copy rule appended by hand and
  `proprietary/vendor/lib64/libwifi-hal-mtk.so` was copied from the dump.
  A real `tools/regen.sh` run reproduces both.

### 3.4 `vintf/boratf_framework_compatibility_matrix.xml` — the requested snippet

```xml
<hal format="aidl" optional="true">
    <name>android.hardware.wifi</name>
    <version>1-4</version>
    <interface><name>IWifi</name><instance>default</instance></interface>
</hal>
<hal format="aidl" optional="true">
    <name>android.hardware.wifi.hostapd</name>
    <version>1-3</version>
    <interface><name>IHostapd</name><instance>default</instance></interface>
</hal>
<hal format="aidl" optional="true">
    <name>android.hardware.wifi.supplicant</name>
    <version>1-5</version>
    <interface><name>ISupplicant</name><instance>default</instance></interface>
</hal>
```

Level 7 only describes the HIDL Wi-Fi HAL (and supplicant/hostapd at v1), while
this build provides AIDL v4/v3/v5 — hence the ranges. The entries follow the
same pattern the tree already uses for the TCT/TCL vendor HALs and
`hardware/mediatek/vintf/mediatek_framework_compatibility_matrix_aidl.xml`
(140 entries). Note that entries are *merged*, not replaced: duplicate HAL
entries across matrix files are fine (the radio HALs are declared in both MTK's
file and the AOSP matrices).

## 4. What the proposal got right and wrong

| Claim | Verdict |
|---|---|
| Open-source AIDL services can drive the existing 64-bit MTK blobs | **right** — this is now what Wi-Fi does |
| Health: replace the HIDL service with an AOSP AIDL service | **already done** — the tree builds `hardware/mediatek/aidl/health` (`IHealth` v5); the HIDL health libs are already dropped. The generic `health-service.example` would work but loses the MTK charging/bootmode handling, so it was not adopted |
| Wi-Fi: "AOSP AIDL wifi-service + supplicant is a 100 % drop-in replacement" | **right in effect, wrong in mechanism** — the AIDL HAL needs a *vendor driver plugin*: there is no `libwifi-hal-*.so` shipped by this vendor, the stock `libwifi-hal.so` **is** the driver interface and has to be reinstalled under the wrapper's `libwifi-hal-mtk.so` name. Nothing "talks nl80211" directly: association goes through AIDL wpa_supplicant |
| Bluetooth: use `bluetooth-service.default` + `libbt-vendor.so` | **equivalent, not needed** — `hardware/mediatek/aidl/bluetooth` already provides the AOSP AIDL `IBluetoothHci` and loads the same `libbt-vendor.so` |
| Audio: AIDL wrapper or keep `audio@7.0` | **keep HIDL 7.1** — level 7 lists HIDL audio 7.0-1, and no AIDL wrapper can drive an `audio.primary.mt6765.so` that speaks HIDL 7.x |
| GNSS: keep HIDL 2.1 and declare it in `framework_compatibility_matrix.xml` | **keep HIDL is right, the declaration is unnecessary** — level 7 already lists HIDL gnss 2.0-1, and the stock `gnss-default.xml` fragment already declares AIDL gnss. No entry added |
| "Delete the old HIDL XML fragments or hwservicemanager and VINTF will fail at boot expecting the old HIDL service" | **wrong** — HIDL and AIDL services coexist; VINTF is a static manifest check and does not require a service to register. The real failure mode is a *duplicate/conflicting entry in one manifest* (this tree already hit it: `Duplicated manifest.hal entry android.hardware.wifi`-style error for `android.hardware.audio` 7.0 vs 7.1, fixed by merging the two `<hal>` blocks) or a Kati/fsgen duplicate *install* when the platform and the blob tree ship the same path (that is what `tools/drop-blobs.txt` is for) |

## 5. Verification done in the clone

* XML well-formedness: both `manifest.xml` and the compatibility matrix parse.
* `tools/gen-blobs.py` re-run: diff of `proprietary-files.txt` is exactly the
  two intended lines.
* `tools/filter-conflicts.py` re-run against the live install set
  (`out/soong/installs-lineage_boratf.mk`): no new conflicts, no unintended
  drop entries.
* Every `PRODUCT_PACKAGES` name above exists in the Soong graph of this tree
  (`out/soong/installs-lineage_boratf.mk`): `android.hardware.wifi-service`,
  `wpa_supplicant`, `hostapd`, `wlan_assistant`, `libwifi-hal-wrapper` + its
  `libwifi-hal-wrapper.xml`.
* `verify/check-vintf.sh` (in the clone) re-runs the build's own checks against
  the staged product dirs; on the unchanged live tree it reproduces
  `COMPATIBLE` for both the compatibility check and the vendor manifest check,
  so the harness itself is trusted. `assemble_vintf -c` is *not* usable on its
  own: it aborts on the sepolicy version check and never reaches the HALs.
* Stock evidence read from the dump: `libwifi-hal.so` symbol table,
  `android.hardware.wifi@1.0-service-lazy` `DT_NEEDED` (links `libwifi-hal.so`),
  stock supplicant/hostapd fragments (HIDL 1.4/1.3) and rc.

## 6. Verification that still needs a build / the device

1. `lunch lineage_boratf cp2a userdebug && m` — the new packages must build and
   `checkvintf` must stay `COMPATIBLE` (see
   `out/target/product/boratf/obj/PACKAGING/check_vintf_all_intermediates/`).
2. On device: `logcat` for `WifiLegacyHalFactory` (vendor HAL plugin found),
   `SupplicantStaIfaceHal` (`ISupplicant/default` found) and `wpa_supplicant`
   starting; `/vendor/etc/wifi/vendor_hals/libwifi-hal-wrapper.xml` present.
3. The mainline supplicant inside the Wi-Fi APEX (`wpa_supplicant_mainline`) is
   still shipped; if the framework prefers it over the vendor supplicant, the
   symptom is an AIDL supplicant that ignores `/vendor/etc/wifi/wpa_supplicant.conf`
   — check which one registers first in `logcat`.
4. `android.hardware.wifi@1.0-service-lazy` is inert but harmless; dropping it
   (plus its rc and fragment) is a follow-up that must be re-validated with
   `checkvintf`, because level 7 does list the HIDL Wi-Fi interface.

## 7. Build log for this change

**Iteration 1 — kati failure (fixed, 2026-11-13):**

```
FAILED:
build/make/core/Makefile:139: error: overriding commands for target
`out/target/product/boratf/vendor/etc/init/android.hardware.wifi.supplicant-service.rc',
previously defined at out/soong/installs-lineage_boratf.mk:611705
```

Enabling `wifi_hidl_unified_supplicant_service_rc_entry` makes the platform
install its AIDL rc at the path the *stock* rc occupies, so the generated
`vendor/tcl/boratf/boratf-vendor.mk` has to stop copying the stock file.
`tools/drop-blobs.txt` and `proprietary-files.txt` were already correct — the
*generated* makefile was the missing half (the clone is not a full AOSP tree,
so the vendor tree was hand-patched instead of re-extracted, and the removal
was missed on the first pass; `tools/regen.sh` does both automatically).

Fixed by deleting that one copy rule. Cross-check over every path the new
packages install (`android.hardware.wifi-service`, `wpa_supplicant`,
`hostapd`, `wlan_assistant`, `libwifi-hal-wrapper`): zero remaining blob copy
rules for them, exactly one for the intentionally kept stock HIDL
`android.hardware.wifi@1.0-service-lazy`, one for the renamed
`libwifi-hal-mtk.so`.
