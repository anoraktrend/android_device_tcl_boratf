#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/tcl/boratf

# --------------------------------------------------------------------
# Audio (HAL service rebuilt from hardware/mediatek; MTK audio blobs
# stay in vendor/tcl/boratf)
#
# android.hardware.audio.service.mediatek builds 64-bit (the
# hardware/mediatek default; stock shipped a 32-bit service), so the
# AOSP sub-HALs it loads at runtime must be installed for 64-bit too:
#   - android.hardware.bluetooth.audio-impl: dlopened by the audio
#     service to register the AIDL Bluetooth audio provider factory
#     (registerExternalServiceImplementations() in the MTK service);
#   - audio.bluetooth.default (BT SCO), audio.usb.default,
#     audio.r_submix.default: hw_get_module sub-HALs of the audio HAL.
# No ABI suffix installs both 32- and 64-bit copies (the matching stock
# blobs are dropped in tools/drop-blobs.txt for both ABIs).
# --------------------------------------------------------------------
PRODUCT_PACKAGES += \
    android.hardware.audio.service.mediatek

PRODUCT_PACKAGES += \
    audio.bluetooth.default \
    audio.r_submix.default \
    audio.usb.default \
    android.hardware.bluetooth.audio-impl

# --------------------------------------------------------------------
# Bluetooth (HIDL service replaced by AIDL from hardware/mediatek)
# --------------------------------------------------------------------
PRODUCT_PACKAGES += \
    android.hardware.bluetooth-service.mediatek

# --------------------------------------------------------------------
# Camera (stock HIDL 2.x camera stack is kept as blobs)
# --------------------------------------------------------------------

# --------------------------------------------------------------------
# Display
# --------------------------------------------------------------------
PRODUCT_PACKAGES += \
    android.hardware.graphics.composer@2.1-service \
    android.hardware.memtrack-service.mediatek

# Feature/permission XMLs for the blob HALs all come from the stock vendor
# partition (vendor/etc/permissions); the build must not install its own copies.

# --------------------------------------------------------------------
# DRM
# --------------------------------------------------------------------
PRODUCT_PACKAGES += \
    android.hardware.drm-service.clearkey

# --------------------------------------------------------------------
# Gatekeeper (service rebuilt; trustonic impl blob is kept)
# --------------------------------------------------------------------
PRODUCT_PACKAGES += \
    android.hardware.gatekeeper@1.0-service \
    android.hardware.gatekeeper@1.0-impl:64

# --------------------------------------------------------------------
# Health
# --------------------------------------------------------------------
PRODUCT_PACKAGES += \
    android.hardware.health-service.mediatek \
    android.hardware.health-service.mediatek-recovery

# --------------------------------------------------------------------
# Init / fstab
# ro.hardware is mt6762 on this device; both names are installed.
# --------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/init/fstab.mt6765:$(TARGET_COPY_OUT_RAMDISK)/fstab.mt6762 \
    $(DEVICE_PATH)/init/fstab.mt6765:$(TARGET_COPY_OUT_RAMDISK)/fstab.mt6765 \
    $(DEVICE_PATH)/init/fstab.mt6765:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.mt6762 \
    $(DEVICE_PATH)/init/fstab.mt6765:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.mt6765

# --------------------------------------------------------------------
# ION (legacy MTK ion)
# --------------------------------------------------------------------
$(call soong_config_set_bool,libion,legacy_impl,true)

# --------------------------------------------------------------------
# IMS / telephony framework support
# --------------------------------------------------------------------
$(call inherit-product, hardware/lineage/compat/frameworks/compat.mk)
$(call inherit-product, hardware/mediatek/frameworks/mediatek-frameworks.mk)

# --------------------------------------------------------------------
# Lights (AIDL, lineage)
# --------------------------------------------------------------------
PRODUCT_PACKAGES += \
    android.hardware.light-service.lineage

# --------------------------------------------------------------------
# Overlay / RRO
# --------------------------------------------------------------------
PRODUCT_ENFORCE_RRO_TARGETS := *

# --------------------------------------------------------------------
# Partitions
# --------------------------------------------------------------------
PRODUCT_USE_DYNAMIC_PARTITIONS := true



# Recovery is built separately (source-built TWRP); the ROM must never
# overwrite the recovery partition.
PRODUCT_BUILD_RECOVERY_IMAGE := false

$(call inherit-product, hardware/mediatek/overlay/mssi.mk)

# --------------------------------------------------------------------
# Power (AIDL lineage-libperfmgr + MTK power stub)
# --------------------------------------------------------------------
PRODUCT_PACKAGES += \
    android.hardware.power-service.lineage-libperfmgr \
    vendor.mediatek.hardware.mtkpower@1.2-service.stub \
    libmtkperf_client

PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/configs/powerhint_mt6765.json:$(TARGET_COPY_OUT_VENDOR)/etc/powerhint_mt6765.json

# --------------------------------------------------------------------
# Properties
# --------------------------------------------------------------------
include hardware/mediatek/configs/properties/vendor_logtag.mk

# --------------------------------------------------------------------
# RIL
# --------------------------------------------------------------------
ENABLE_VENDOR_RIL_SERVICE := true

# --------------------------------------------------------------------
# Sensors (AIDL multihal + HIDL 2.0 subhal shim; MTK sensor blobs and
# /vendor/etc/sensors/hals.conf stay stock)
# --------------------------------------------------------------------
PRODUCT_PACKAGES += \
    android.hardware.sensors-service.multihal \
    android.hardware.sensors@2.0-subhal-impl-1.0

# --------------------------------------------------------------------
# Soong namespaces
# --------------------------------------------------------------------
PRODUCT_SOONG_NAMESPACES += \
    $(DEVICE_PATH) \
    hardware/google/interfaces \
    hardware/google/pixel/pixelstats \
    hardware/google/pixel/power-libperfmgr \
    hardware/google/pixel/thermal \
    hardware/lineage/interfaces/power-libperfmgr \
    hardware/mediatek \
    hardware/mediatek/libmtkperf_client

# --------------------------------------------------------------------
# Thermal (AIDL service rebuilt; MTK thermal daemons stay stock)
# --------------------------------------------------------------------
PRODUCT_PACKAGES += \
    android.hardware.thermal-service.mediatek

PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/configs/thermal_info_config.json:$(TARGET_COPY_OUT_VENDOR)/etc/thermal_info_config.json

# --------------------------------------------------------------------
# USB (AIDL services rebuilt from hardware/mediatek)
# --------------------------------------------------------------------
PRODUCT_PACKAGES += \
    android.hardware.usb-service.mediatek \
    android.hardware.usb.gadget-service.mediatek

# --------------------------------------------------------------------
# Vibrator (AIDL service rebuilt from hardware/mediatek)
# --------------------------------------------------------------------
PRODUCT_PACKAGES += \
    android.hardware.vibrator-service.mediatek

# --------------------------------------------------------------------
# Wi-Fi (AIDL HAL + the stock MTK legacy driver plugin)
#
# The LineageOS 24 Wi-Fi stack is AIDL-only (packages/modules/Wifi has no
# HIDL client left), so the stock HIDL service
# (android.hardware.wifi@1.0-service-lazy, still declared by the stock
# fragment for FCM compatibility) is never used by the framework. The AIDL
# HAL is generic and takes the driver interface from a *vendor* plugin
# described by /vendor/etc/wifi/vendor_hals/*.xml:
#
#   android.hardware.wifi-service        (AOSP, built for /vendor)
#     -> /vendor/etc/wifi/vendor_hals/libwifi-hal-wrapper.xml
#        -> /vendor/lib64/libwifi-hal-wrapper.so   (hardware/mediatek)
#           -> dlopen("libwifi-hal-mtk.so")
#              = the stock MTK legacy Wi-Fi HAL (init_wifi_vendor_hal_func_table,
#                180 exported functions), installed under that name
#                because the platform now occupies libwifi-hal.so itself
#                (frameworks/opt/net/wifi/libwifi_hal).
#
# The wrapper accepts the pre-Android-14 legacy struct layout this Android 13
# vendor library was built against.
#
# wpa_supplicant/hostapd are the AOSP AIDL implementations: the stock ones
# are HIDL 1.4/1.3 services (never needed by this framework), while FCM 7
# only declares the AIDL supplicant/hostapd interfaces. They drive the same
# wmt_drv.ko via nl80211 and reuse the stock /vendor/etc/wifi/*.conf.
# --------------------------------------------------------------------
PRODUCT_PACKAGES += \
    android.hardware.wifi-service \
    hostapd \
    libwifi-hal-wrapper \
    wlan_assistant \
    wpa_supplicant

# The AIDL supplicant rc is only installed when this is set; the stock rc
# (vendor/etc/init/android.hardware.wifi.supplicant-service.rc) declares
# HIDL interfaces and is dropped in tools/drop-blobs.txt in favour of it.
$(call soong_config_set_bool,wpa_supplicant_8,wifi_hidl_unified_supplicant_service_rc_entry,true)

# ABI of the stock legacy Wi-Fi HAL: built before Android 14 QPR2 (U), so the
# older wifi_hal function-table layout must be used by the wrapper.
$(call soong_config_set_bool,mediatek_wifi_hal,use_pre_u_qpr2_struct,true)
$(call soong_config_set_bool,mediatek_wifi_hal,use_pre_baklava_qpr0_struct,true)

# --------------------------------------------------------------------
# Platform compat libraries for the stock vendor HALs
#
# The stock MTK vendor is self-contained, but the libraries its shipped ELFs
# link against include ones the platform provides as *vendor compat* modules:
# HIDL interface libraries (audio 7.0, camera.provider 2.x, wifi 1.x,
# radio 1.x, secure_element, tetheroffload, ...), MTK interface libraries
# (vendor.mediatek.hardware.*) and MTK-specific shims (libaedv, libladder,
# libmnl, libprotobuf-cpp-lite-3.9.1-vendorcompat, libkeystore-wifi-hidl,
# libmtkperf_client_vendor, libpowerhalwrap_vendor, ...).
#
# tools/filter-conflicts.py dropped the stock copies of those paths because
# the platform *stages* them; unless the modules are selected here neither
# side ships them and every depending vendor binary fails to exec with
# "CANNOT LINK EXECUTABLE: library ... not found"
# (verified: readelf -d over all 928 vendor ELFs vs the built images found
# 66 such libraries, e.g. needed by mnld, camerahalserver, the audio and
# keymaster impls, secure_element and the stock HIDL wifi service).
#
# libMegvii/libmegface are deliberately absent (prohibited-files policy).
# --------------------------------------------------------------------

# The vendor variants of those libraries are installed by this dependency
# carrier module (see vendor_compat/Android.bp): PRODUCT_PACKAGES alone only
# installs the platform variants into /system, which vendor processes cannot
# load.
PRODUCT_PACKAGES += \
    boratf_vendor_compat_libs
PRODUCT_PACKAGES += \
    android.hardware.audio.common@7.0 \
    android.hardware.audio.common@7.0-enums \
    android.hardware.audio.common@7.0-util \
    android.hardware.audio.effect@7.0 \
    android.hardware.audio@7.0 \
    android.hardware.audio@7.0-util \
    android.hardware.biometrics.face@1.0 \
    android.hardware.bluetooth@1.0 \
    android.hardware.bluetooth@1.1 \
    android.hardware.camera.provider@2.4 \
    android.hardware.camera.provider@2.5 \
    android.hardware.camera.provider@2.6 \
    android.hardware.radio.config@1.0 \
    android.hardware.radio.config@1.1 \
    android.hardware.radio.config@1.2 \
    android.hardware.radio.config@1.3 \
    android.hardware.radio@1.2 \
    android.hardware.radio@1.3 \
    android.hardware.radio@1.4 \
    android.hardware.radio@1.5 \
    android.hardware.radio@1.6 \
    android.hardware.secure_element@1.0 \
    android.hardware.secure_element@1.1 \
    android.hardware.secure_element@1.2 \
    android.hardware.tetheroffload.config@1.0 \
    android.hardware.tetheroffload.control@1.0 \
    android.hardware.tetheroffload.control@1.1 \
    android.hardware.wifi@1.0 \
    android.hardware.wifi@1.1 \
    android.hardware.wifi@1.2 \
    android.hardware.wifi@1.3 \
    android.hardware.wifi@1.4 \
    android.hardware.wifi@1.5 \
    libaedv \
    libavservices_minijail_vendor \
    libcamera2ndk_vendor \
    libcodec2_hidl@1.0 \
    libcodec2_hidl@1.1 \
    libcodec2_hidl@1.2 \
    libcodec2_soft_common \
    libcurl \
    libdrm \
    libhidltransport \
    libhwbinder \
    libkeymaster4 \
    libkeymaster41 \
    libkeystore-wifi-hidl \
    libladder \
    libmnl \
    libmtkperf_client_vendor \
    libopus \
    libpowerhalwrap_vendor \
    libprotobuf-cpp-lite-3.9.1-vendorcompat \
    libsensorndkbridge \
    libstagefright_enc_common \
    libstagefright_flacdec \
    libstagefright_softomx \
    libtinycompress \
    libvorbisidec \
    libvpx \
    vendor.mediatek.hardware.bluetooth.audio@2.1 \
    vendor.mediatek.hardware.bluetooth.audio@2.2 \
    vendor.mediatek.hardware.lbs@1.0 \
    vendor.mediatek.hardware.log@1.0 \
    vendor.mediatek.hardware.mtkradioex@2.0 \
    vendor.mediatek.hardware.mtkradioex@3.0 \
    vendor.mediatek.hardware.netdagent@1.0

# --------------------------------------------------------------------
# Proprietary files
# --------------------------------------------------------------------
$(call inherit-product, vendor/tcl/boratf/boratf-vendor.mk)

# The stock 4.19.325 vendor kernel cannot satisfy the FCM 7 kernel config
# requirements (e.g. CONFIG_CFI_CLANG, CONFIG_SHADOW_CALL_STACK). Skip the
# build-time checkvintf kernel requirements check; the HAL compatibility
# checks remain enabled.
PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false
