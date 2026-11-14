#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from the common products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit common LineageOS bits.
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

# Device configuration.
$(call inherit-product, device/tcl/boratf/device.mk)

PRODUCT_NAME := lineage_boratf
PRODUCT_DEVICE := boratf
PRODUCT_BRAND := TCL
PRODUCT_MODEL := TCL Ion V
PRODUCT_MANUFACTURER := TCL
