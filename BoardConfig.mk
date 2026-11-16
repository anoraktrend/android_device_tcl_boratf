#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/tcl/boratf

# --------------------------------------------------------------------
# Build compatibility flags
#
# The stock vendor partition is self-contained: its ~1600 blobs (including
# platform-provided libraries and the stock vintf fragments) are installed
# verbatim with raw copy rules, deliberately without Soong modules. Soong
# modules for them would collide with the platform's own modules of the same
# names (partition/module clashes), so until/unless the blob list is curated
# back to module-based prebuilts these two legacy checks are disabled.
# --------------------------------------------------------------------
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BUILD_BROKEN_VINTF_PRODUCT_COPY_FILES := true

# --------------------------------------------------------------------
# Architecture (MT6765, 64-bit with 32-bit secondary)
# --------------------------------------------------------------------
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := cortex-a53

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := cortex-a53

TARGET_BOARD_PLATFORM := mt6765
TARGET_BOOTLOADER_BOARD_NAME := mt6765

# --------------------------------------------------------------------
# Boot image (header v2, stock layout, A-only)
# Stock: kernel_addr 0x40080000, ramdisk_addr 0x51b00000,
#        tags_addr/dtb_addr 0x47880000, pagesize 2048
# --------------------------------------------------------------------
BOARD_KERNEL_BASE := 0x40078000
BOARD_KERNEL_OFFSET := 0x00008000
BOARD_KERNEL_PAGESIZE := 2048
BOARD_KERNEL_TAGS_OFFSET := 0x07808000
BOARD_RAMDISK_OFFSET := 0x11A88000
BOARD_DTB_OFFSET := 0x07808000

BOARD_BOOTIMG_HEADER_VERSION := 2
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
BOARD_PREBUILT_DTBIMAGE_DIR := $(DEVICE_PATH)/prebuilts/dtb

BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2

BOARD_MKBOOTIMG_ARGS := --base $(BOARD_KERNEL_BASE)
BOARD_MKBOOTIMG_ARGS += --kernel_offset $(BOARD_KERNEL_OFFSET)
BOARD_MKBOOTIMG_ARGS += --ramdisk_offset $(BOARD_RAMDISK_OFFSET)
BOARD_MKBOOTIMG_ARGS += --tags_offset $(BOARD_KERNEL_TAGS_OFFSET)
BOARD_MKBOOTIMG_ARGS += --dtb_offset $(BOARD_DTB_OFFSET)
BOARD_MKBOOTIMG_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOTIMG_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --board ""

# --------------------------------------------------------------------
# Kernel (in-tree source: kernel/tcl/boratf; TCL/MT6765 fork)
# Standalone equivalent:
#   make O=out ARCH=arm64 CC=clang CLANG_TRIPLE=aarch64-linux-gnu- \
#        CROSS_COMPILE=aarch64-linux-gnu- bora_tf_live_defconfig Image.gz
# --------------------------------------------------------------------
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
TARGET_KERNEL_SOURCE := kernel/tcl/boratf
TARGET_KERNEL_CONFIG := bora_tf_live_defconfig
TARGET_KERNEL_NO_GCC := true

# clang-r383902 is the toolchain the boratf kernel is validated against.
# Override with TARGET_KERNEL_CLANG_PATH or place the clang in this path.
TARGET_KERNEL_CLANG_PATH ?= /home/lucy/Downloads/android-clang-r383902

BOARD_KERNEL_IMAGE_NAME := Image.gz

# --------------------------------------------------------------------
# Partitions (MTK A-only, native dynamic partitions, no slot suffix)
# --------------------------------------------------------------------
# Android 17 defaults AB_OTA_UPDATER to true when it is unset
# (build/make/core/board_config.mk), which would turn this into an A/B
# build: _a/_b slot suffixes on every logical partition plus the
# "sum(groups) < super/2" check that rejects using the whole super.
# The device has a single slot, so opt out explicitly.
AB_OTA_UPDATER := false

BOARD_FLASH_BLOCK_SIZE := 262144 # (BOARD_KERNEL_PAGESIZE * 64)

BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 67108864
BOARD_DTBOIMG_PARTITION_SIZE := 8388608

# Stock super: 8192 MiB total, single group "main" (8190 MiB).
# Stock logical partitions: odm 10 MiB, oem 1052 MiB, preload 194 MiB,
# product 2259 MiB, system 3035 MiB, vendor 625 MiB. oem/preload are not
# shipped (fstab marks them nofail); vendor is enlarged for the built HALs.
BOARD_SUPER_PARTITION_SIZE := 8589934592
BOARD_SUPER_PARTITION_GROUPS := main
BOARD_MAIN_PARTITION_LIST := system vendor product odm
BOARD_MAIN_SIZE := 8587837440

# This device flashes the super partition directly (no OTA package), so
# make super.img part of the default `m` target instead of only `m superimage`.
BOARD_BUILD_SUPER_IMAGE_BY_DEFAULT := true

# Logical partitions are auto-sized (PRODUCT_USE_DYNAMIC_PARTITION_SIZE);
# the reserved sizes below add headroom on top of the image contents.
BOARD_SYSTEMIMAGE_PARTITION_RESERVED_SIZE := 268435456
BOARD_PRODUCTIMAGE_PARTITION_RESERVED_SIZE := 838860800
BOARD_VENDORIMAGE_PARTITION_RESERVED_SIZE := 134217728
BOARD_ODMIMAGE_PARTITION_RESERVED_SIZE := 2097152

# No dedicated system_ext partition on this device (fused into system)
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_ODMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_USES_ODMIMAGE := true

TARGET_COPY_OUT_PRODUCT := product
TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_ODM := odm

BOARD_USES_METADATA_PARTITION := true

# Keep the stock dtbo partition image (device tree is a bring-up WIP;
# the kernel does not produce boratf DTBs yet).
BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/prebuilts/dtbo.img

-include vendor/lineage/config/BoardConfigReservedSize.mk

# --------------------------------------------------------------------
# Platform
# --------------------------------------------------------------------
BOARD_HAS_MTK_HARDWARE := true

# Stock vendor is an Android 12 (API 31) prebuilt; keep the system side
# building against the VNDK 31 snapshot.
BOARD_VNDK_VERSION := 31

# --------------------------------------------------------------------
# Properties
# --------------------------------------------------------------------
TARGET_SYSTEM_PROP += $(DEVICE_PATH)/system.prop
TARGET_VENDOR_PROP += $(DEVICE_PATH)/vendor.prop
TARGET_PRODUCT_PROP += $(DEVICE_PATH)/product.prop

# --------------------------------------------------------------------
# Recovery
# --------------------------------------------------------------------
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/init/fstab.mt6765
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_USERIMAGES_USE_F2FS := true

# --------------------------------------------------------------------
# SEPolicy
# --------------------------------------------------------------------
include device/lineage/sepolicy/libion/sepolicy.mk
include device/mediatek/sepolicy_vndr/SEPolicy.mk
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor
SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/private
SYSTEM_EXT_PUBLIC_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/public

# --------------------------------------------------------------------
# Verified boot (user flashes with verification disabled; test keys)
# --------------------------------------------------------------------
BOARD_AVB_ENABLE := true
BOARD_AVB_ALGORITHM := SHA256_RSA2048
BOARD_AVB_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --set_hashtree_disabled_flag

BOARD_AVB_BOOT_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_BOOT_ALGORITHM := SHA256_RSA2048
BOARD_AVB_BOOT_ROLLBACK_INDEX := 1
BOARD_AVB_BOOT_ROLLBACK_INDEX_LOCATION := 1

BOARD_AVB_RECOVERY_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_RECOVERY_ALGORITHM := SHA256_RSA2048

BOARD_AVB_VBMETA_SYSTEM := system
BOARD_AVB_VBMETA_SYSTEM_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_VBMETA_SYSTEM_ALGORITHM := SHA256_RSA2048
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX := 1
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX_LOCATION := 2

BOARD_AVB_VBMETA_VENDOR := vendor
BOARD_AVB_VBMETA_VENDOR_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_VBMETA_VENDOR_ALGORITHM := SHA256_RSA2048
BOARD_AVB_VBMETA_VENDOR_ROLLBACK_INDEX := 1
BOARD_AVB_VBMETA_VENDOR_ROLLBACK_INDEX_LOCATION := 3

# sha256 for dm-verity partitions
BOARD_AVB_SYSTEM_ADD_HASHTREE_FOOTER_ARGS += --hash_algorithm sha256
BOARD_AVB_PRODUCT_ADD_HASHTREE_FOOTER_ARGS += --hash_algorithm sha256
BOARD_AVB_VENDOR_ADD_HASHTREE_FOOTER_ARGS += --hash_algorithm sha256

# --------------------------------------------------------------------
# VINTF
# Device manifest replaces the stock one (some stock HAL services are
# rebuilt from source, so the stock manifest would be inconsistent).
# --------------------------------------------------------------------
DEVICE_MANIFEST_FILE := $(DEVICE_PATH)/manifest.xml
DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE += \
    hardware/mediatek/vintf/mediatek_framework_compatibility_matrix_aidl.xml \
    hardware/mediatek/vintf/mediatek_framework_compatibility_matrix.xml \
    $(DEVICE_PATH)/vintf/boratf_framework_compatibility_matrix.xml

# --------------------------------------------------------------------
# Wi-Fi (MTK connac1x / gen4m)
# --------------------------------------------------------------------
BOARD_HOSTAPD_DRIVER := NL80211
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
WIFI_DRIVER_FW_PATH_PARAM := "/dev/wmtWifi"
WIFI_DRIVER_FW_PATH_STA := "STA"
WIFI_DRIVER_FW_PATH_AP := "AP"
WIFI_DRIVER_FW_PATH_P2P := "P2P"
WIFI_DRIVER_STATE_CTRL_PARAM := "/dev/wmtWifi"
WIFI_DRIVER_STATE_ON := "1"
WIFI_DRIVER_STATE_OFF := "0"
WPA_SUPPLICANT_VERSION := VER_0_8_X

# --------------------------------------------------------------------
# Proprietary files
# --------------------------------------------------------------------
include vendor/tcl/boratf/BoardConfigVendor.mk
