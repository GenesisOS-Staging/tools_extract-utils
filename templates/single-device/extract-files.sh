#!/bin/bash
#
# SPDX-FileCopyrightText: 2016 The CyanogenMod Project
# SPDX-FileCopyrightText: 2017-2024 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=**** FILL IN DEVICE NAME ****
VENDOR=**** FILL IN VENDOR NAME ****

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

ONLY_FIRMWARE=
KANG=
SECTION=
CARRIER_SKIP_FILES=()

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        --only-firmware)
            ONLY_FIRMWARE=true
            ;;
        -n | --no-cleanup)
            CLEAN_VENDOR=false
            ;;
        -k | --kang)
            KANG="--kang"
            ;;
        -s | --section)
            SECTION="${2}"
            shift
            CLEAN_VENDOR=false
            ;;
        *)
            SRC="${1}"
            ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in
        vendor/lib/libsample1.so)
            [ "$2" = "" ] && return 0
            sed -i 's|/data/misc/sample1|/data/misc/sample2|g' "${2}"
            ;;
        vendor/lib64/libsample2.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --remove-needed "libsample3.so" "${2}"
            "${PATCHELF}" --add-needed "libsample4.so" "${2}"
            ;;
        vendor/lib/libsample5.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --replace-needed "libsample6.so" "libsample7.so" "${2}"
            ;;
        vendor/lib/libsample7.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --set-soname "libsample7.so" "${2}"
            ;;
        *)
            return 1
            ;;
    esac

    return 0
}

function blob_fixup_dry() {
    blob_fixup "$1" ""
}

function prepare_firmware() {
    if [ "${SRC}" != "adb" ]; then
        local STAR="${ANDROID_ROOT}"/lineage/scripts/motorola/star.sh
        for IMAGE in bootloader radio; do
            if [ -f "${SRC}/${IMAGE}.img" ]; then
                echo "Extracting Motorola star image ${SRC}/${IMAGE}.img"
                sh "${STAR}" "${SRC}/${IMAGE}.img" "${SRC}"
            fi
        done
    fi
}

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

if [ -z "${ONLY_FIRMWARE}" ]; then
    extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"

    generate_prop_list_from_image "product.img" "${MY_DIR}/proprietary-files-carriersettings.txt" CARRIER_SKIP_FILES carriersettings
    extract "${MY_DIR}/proprietary-files-carriersettings.txt" "${SRC}" "${KANG}" --section "${SECTION}"

    extract_carriersettings
fi

if [ -z "${SECTION}" ]; then
    extract_firmware "${MY_DIR}/proprietary-firmware.txt" "${SRC}"
fi

"${MY_DIR}/setup-makefiles.sh"
