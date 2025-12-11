#!/bin/sh
# build script for Econet en75xx boot components converted from Makefile
# Usage:
#   SOC=en7523 ./build.sh
# Optional env vars to override:
#   TARGET_CROSS, LINUX_KARCH, RELEASE_SRC_PATH, RELEASECODE, REBUILDCODE,
#   TCSUPPORT_CPU_EN7523, TCSUPPORT_CPU_EN7581, TCSUPPORT_BL2_OPTIMIZATION,
#   TCSUPPORT_ARM_SECURE_BOOT, CONFIG_TARGET_econet_en7580,
#   ECNT_BUILD_DIR, LINUX_DIR, TRUNK_DIR, BIN_DIR,
#   TCSUPPORT_UBOOT_VERSION, TCSUPPORT_ATF_VERSION, PROFILE_DIR, OPTEE_DIR

set -e

if [ -z "${SOC}" ]; then
  echo "Usage: SOC=<en7523|en7581|en7512|en7521|mt7510|mt7520|mt7505|en7580> $0"
  exit 1
fi

TARGET_CROSS="${TARGET_CROSS:-aarch64-linux-gnu-}"
LINUX_KARCH="${LINUX_KARCH:-arm64}"
RELEASE_SRC_PATH="${RELEASE_SRC_PATH:-default}"
RELEASECODE="${RELEASECODE:-}"        # non-empty -> do boot release
REBUILDCODE="${REBUILDCODE:-}"        # non-empty -> run EcntPrepare
TRUNK_DIR="${TRUNK_DIR:-$(pwd)}"
ECNT_BUILD_DIR="${ECNT_BUILD_DIR:-$(pwd)}"
LINUX_DIR="${LINUX_DIR:-/path/to/linux}"
BIN_DIR="${BIN_DIR:-$(pwd)/bin}"

# Map SOC to flags
case "${SOC}" in
  en7523)
    TCSUPPORT_CPU_EN7523="${TCSUPPORT_CPU_EN7523:-1}"
    TCSOCNAME="${TCSOCNAME:-en7523}"
    ;;
  en7581)
    TCSUPPORT_CPU_EN7523="${TCSUPPORT_CPU_EN7523:-1}"
    TCSUPPORT_CPU_EN7581="${TCSUPPORT_CPU_EN7581:-1}"
    TCSOCNAME="${TCSOCNAME:-en7581}"
    ;;
  en7512)
    TCSUPPORT_CPU_EN7512="${TCSUPPORT_CPU_EN7512:-1}"
    TCSOCNAME="${TCSOCNAME:-en7512}"
    ;;
  en7521)
    TCSUPPORT_CPU_EN7521="${TCSUPPORT_CPU_EN7521:-1}"
    TCSOCNAME="${TCSOCNAME:-en7521}"
    ;;
  mt7510)
    TCSUPPORT_CPU_MT7510="${TCSUPPORT_CPU_MT7510:-1}"
    TCSOCNAME="${TCSOCNAME:-mt7510}"
    ;;
  mt7520)
    TCSUPPORT_CPU_MT7520="${TCSUPPORT_CPU_MT7520:-1}"
    TCSOCNAME="${TCSOCNAME:-mt7520}"
    ;;
  mt7505)
    TCSUPPORT_CPU_MT7505="${TCSUPPORT_CPU_MT7505:-1}"
    TCSOCNAME="${TCSOCNAME:-mt7505}"
    ;;
  en7580)
    TCSUPPORT_CPU_EN7580="${TCSUPPORT_CPU_EN7580:-1}"
    TCSOCNAME="${TCSOCNAME:-en7580}"
    ;;
  *)
    TCSOCNAME="${TCSOCNAME:-${SOC}}"
    ;;
esac

echo "Checking cross compiler: ${TARGET_CROSS}gcc"
if ! command -v "${TARGET_CROSS}gcc" >/dev/null 2>&1; then
  echo "Error: ${TARGET_CROSS}gcc not found in PATH"
  exit 1
fi

PKG_BUILD_DIR="$(pwd)/build-tcboot"
UNOPEN_IMG_PATH="unopen_img/${RELEASE_SRC_PATH}/atf"

# Defaults for internal dirs (relative to PKG_BUILD_DIR/src)
# You may need to adjust these to match your repo layout.
UBOOT_DIR_DEFAULT="${PKG_BUILD_DIR}/src/Uboot"
ATF_DIR_DEFAULT="${PKG_BUILD_DIR}/src/ATF"
PROFILE_DIR_DEFAULT="${PKG_BUILD_DIR}/src/profile"
TOOLS_DIR_DEFAULT="${PKG_BUILD_DIR}/tools"
TOOLS_UBOOT_DIR_DEFAULT="${PKG_BUILD_DIR}/tools"
BOOTROM_DIR_DEFAULT="${PKG_BUILD_DIR}/src/bootrom"

# U-Boot/ATF version directory names used by make_bootbase
TCSUPPORT_UBOOT_VERSION="${TCSUPPORT_UBOOT_VERSION:-u-boot-2014.04-rc1}"
TCSUPPORT_ATF_VERSION="${TCSUPPORT_ATF_VERSION:-arm-trusted-firmware-2.3}"

# Compose MAKE_OPTS from Makefile logic
MAKE_OPTS=""
if [ -n "${TCSUPPORT_CPU_EN7523}" ]; then
  if [ -n "${TCSUPPORT_CPU_EN7581}" ]; then
    export UBOOT_CONFIG="an7581"
    export TOOLCHAIN_BASE="/opt/trendchip/buildroot-gcc1030-glibc232_kernel5_4/usr"
  fi
  MAKE_OPTS="${MAKE_OPTS} CROSS_COMPILE=${TARGET_CROSS}"
  if [ -z "${REBUILDCODE}" ]; then
    MAKE_OPTS="${MAKE_OPTS} TCSUPPORT_OPENWRT_RELEASECODE=${RELEASECODE:-1}"
  else
    MAKE_OPTS="${MAKE_OPTS} TCSUPPORT_OPENWRT_RELEASECODE="
  fi
else
  MAKE_OPTS="${MAKE_OPTS} ARCH=${LINUX_KARCH} CROSS_COMPILE=${TARGET_CROSS} SUBDIRS=${PKG_BUILD_DIR} TCSUPPORT_OPENWRT_RELEASE_SRC_PATH=${RELEASE_SRC_PATH}"
  if [ -z "${RELEASECODE}" ]; then
    MAKE_OPTS="${MAKE_OPTS} TC_BUILD_RELEASECODE=1"
  fi
fi

MAKE_FLAGS="SUBDIRS=${PKG_BUILD_DIR}"

cpv() {
  mkdir -p "$(dirname "$2")"
  cp -rf $1 $2
}

ecnt_prepare() {
  if [ -n "${TCSUPPORT_CPU_EN7523}" ]; then
    rm -rf ./tools
    mkdir -p ./tools
    cpv "${TRUNK_DIR}/bootloader" "./bootloader"

    make -C "${TRUNK_DIR}/tools/lzma432/7zip/Compress/LZMA_Alone/" clean || true
    make -C "${TRUNK_DIR}/tools/lzma432/7zip/Compress/LZMA_Alone/"
    cpv "${TRUNK_DIR}/tools/lzma432/7zip/Compress/LZMA_Alone/lzma" "./tools"

    make -C "${TRUNK_DIR}/tools/trx" clean || true
    make -C "${TRUNK_DIR}/tools/trx"
    cpv "${TRUNK_DIR}/tools/trx" "./tools"
    if [ -n "${TCSUPPORT_BL2_OPTIMIZATION}" ]; then
      cpv "${TRUNK_DIR}/tools/flash_table" "./tools/"
    fi
  else
    rm -rf ./bootrom ./tools ./version
    mkdir -p ./bootrom ./tools ./version
    cpv "${TRUNK_DIR}/bootrom/*" "./bootrom"
    cpv "${TRUNK_DIR}/bootrom/openwrt/*" "./bootrom"
    cpv "${TRUNK_DIR}/tools/lzma" "./tools"
    cpv "${TRUNK_DIR}/tools/trx" "./tools"
    cpv "${TRUNK_DIR}/tools/secure_header" "./tools"
    cpv "${TRUNK_DIR}/tools/mbedtls-2.5.1" "./tools"
  fi
}

prepare_stage() {
  if [ -n "${REBUILDCODE}" ]; then
    echo "Running EcntPrepare..."
    ecnt_prepare
  fi

  mkdir -p "${PKG_BUILD_DIR}"

  if [ -n "${TCSUPPORT_CPU_EN7523}" ]; then
    if [ -n "${TCSUPPORT_ARM_SECURE_BOOT}" ]; then
      mkdir -p "${BSP_EXT_TCLINUX_BUILDER}"
      chmod 777 -R "$(pwd)/bootloader/ATF/openssl" || true
    fi
    cp -rf "$(pwd)/bootloader" "${PKG_BUILD_DIR}/src"
  else
    cp -rf "$(pwd)/bootrom" "${PKG_BUILD_DIR}/src"
    chmod 755 "${PKG_BUILD_DIR}/src/byteswap" || true
    cp -rf "$(pwd)/version" "${PKG_BUILD_DIR}/"
  fi

  cp -rf "$(pwd)/tools" "${PKG_BUILD_DIR}/"
  chmod 777 -R "${PKG_BUILD_DIR}/tools" || true

  if [ -f "$(pwd)/tcboot/tcboot.bin" ]; then
    cp -rf "$(pwd)/tcboot" "${PKG_BUILD_DIR}/"
  fi
}

boot_release_stage() {
  if [ -n "${TCSUPPORT_CPU_EN7523}" ]; then
    mkdir -p "$(pwd)/bootloader/${UNOPEN_IMG_PATH}"
    cpv "${PKG_BUILD_DIR}/src/${UNOPEN_IMG_PATH}/*" "$(pwd)/bootloader/${UNOPEN_IMG_PATH}/"
    make -C "$(pwd)/bootloader" -f make_bootbase ATF_DIR="$(pwd)/bootloader/ATF" ${MAKE_OPTS} delete_code
    echo "RELSASED_SDK=1" > release_sdk.mk
  else
    cpv "${PKG_BUILD_DIR}/src/unopen_img/${RELEASE_SRC_PATH}" "./bootrom/unopen_img/"
    if [ -n "${TCSUPPORT_CPU_EN7580}" ]; then
      mkdir -p ./bootrom/unopen_img/${RELEASE_SRC_PATH}/ram_init/output
      cpv "${PKG_BUILD_DIR}/src/ram_init/output/*" "./bootrom/unopen_img/${RELEASE_SRC_PATH}/ram_init/output/"
      cpv "${PKG_BUILD_DIR}/src/ram_init/spram.c" "./bootrom/unopen_img/${RELEASE_SRC_PATH}/ram_init/"
      cpv "${PKG_BUILD_DIR}/src/spram_ext/system.o" "./bootrom/unopen_img/${RELEASE_SRC_PATH}/ram_init/output/"
    elif [ -n "${TCSUPPORT_CPU_EN7512}" ] || [ -n "${TCSUPPORT_CPU_EN7521}" ]; then
      mkdir -p ./bootrom/unopen_img/${RELEASE_SRC_PATH}/ddr_cal_en7512/output
      cpv "${PKG_BUILD_DIR}/src/ddr_cal_en7512/output/*" "./bootrom/unopen_img/${RELEASE_SRC_PATH}/ddr_cal_en7512/output/"
      cpv "${PKG_BUILD_DIR}/src/ddr_cal_en7512/spram.c" "./bootrom/unopen_img/${RELEASE_SRC_PATH}/ddr_cal_en7512/"
      cpv "${PKG_BUILD_DIR}/src/spram_ext/system.o" "./bootrom/unopen_img/${RELEASE_SRC_PATH}/ddr_cal_en7512/output/"
    elif [ -n "${TCSUPPORT_CPU_MT7510}" ] || [ -n "${TCSUPPORT_CPU_MT7520}" ]; then
      mkdir -p ./bootrom/ddr_cal/reserved
      cpv "${PKG_BUILD_DIR}/src/ddr_cal/output/*" "./bootrom/ddr_cal/reserved/"
      cpv "${PKG_BUILD_DIR}/src/ddr_cal/spram.c" "./bootrom/ddr_cal/reserved/"
    elif [ -n "${TCSUPPORT_CPU_MT7505}" ]; then
      mkdir -p ./bootrom/ddr_cal_mt7505/reserved
      cpv "${PKG_BUILD_DIR}/src/ddr_cal_mt7505/output/*" "./bootrom/ddr_cal_mt7505/reserved/"
      cpv "${PKG_BUILD_DIR}/src/ddr_cal_mt7505/spram.c" "./bootrom/ddr_cal_mt7505/reserved/"
    fi
  fi
}

compile_stage() {
  # Derive internal dirs
  UBOOT_DIR="${UBOOT_DIR:-${UBOOT_DIR_DEFAULT}}"
  ATF_DIR="${ATF_DIR:-${ATF_DIR_DEFAULT}}"
  PROFILE_DIR="${PROFILE_DIR:-${PROFILE_DIR_DEFAULT}}"
  TOOLS_DIR="${TOOLS_DIR:-${TOOLS_DIR_DEFAULT}}"
  TOOLS_UBOOT_DIR="${TOOLS_UBOOT_DIR:-${TOOLS_UBOOT_DIR_DEFAULT}}"
  BOOTROM_DIR="${BOOTROM_DIR:-${BOOTROM_DIR_DEFAULT}}"

  # Build bootbase with all required variables for make_bootbase
  make -C "${PKG_BUILD_DIR}/src" -f make_bootbase \
    ${MAKE_OPTS} \
    bootbase \
    TCPLATFORM="${RELEASE_SRC_PATH}" \
    BSP_ROOTDIR="${ECNT_BUILD_DIR}" \
    KERNEL_DIR="${LINUX_DIR}" \
    ATF_DIR="${ATF_DIR}" \
    UBOOT_DIR="${UBOOT_DIR}" \
    TCSUPPORT_UBOOT_VERSION="${TCSUPPORT_UBOOT_VERSION}" \
    TCSUPPORT_ATF_VERSION="${TCSUPPORT_ATF_VERSION}" \
    TCSOCNAME="${TCSOCNAME}" \
    TOOLS_DIR="${TOOLS_DIR}" \
    TOOLS_UBOOT_DIR="${TOOLS_UBOOT_DIR}" \
    PROFILE_DIR="${PROFILE_DIR}" \
    BOOTROM_DIR="${BOOTROM_DIR}"

  if [ -n "${RELEASECODE}" ]; then
    boot_release_stage
  fi

  if [ -n "${CONFIG_TARGET_econet_en7580}" ] && [ -n "${RELEASECODE}" ]; then
    make -C "$(pwd)/" -f "$(pwd)/openwrt_release" OPENWRT_PWD="${PKG_BUILD_DIR}" BOOTROM_DIR="$(pwd)/bootrom/" release_boot
  fi
}

install_stage() {
  mkdir -p "${BIN_DIR}"
  if [ -f "${PKG_BUILD_DIR}/src/tcboot.bin" ]; then
    cpv "${PKG_BUILD_DIR}/src/tcboot.bin" "${BIN_DIR}/tcboot.bin"
  fi
  if [ -f "${PKG_BUILD_DIR}/src/bootext.ram" ]; then
    cpv "${PKG_BUILD_DIR}/src/bootext.ram" "${BIN_DIR}/bootext.ram"
  fi
  if [ -f "${PKG_BUILD_DIR}/src/Uboot/${TCSUPPORT_UBOOT_VERSION}/u-boot.bin" ]; then
    cpv "${PKG_BUILD_DIR}/src/Uboot/${TCSUPPORT_UBOOT_VERSION}/u-boot.bin" "${BIN_DIR}/u-boot.bin"
  fi
  if [ -n "${TCSUPPORT_SECURE_BOOT}" ]; then
    if [ -f "${PKG_BUILD_DIR}/tools/secure_header/sheader" ]; then
      mkdir -p "${STAGING_DIR_HOST}/bin"
      cpv "${PKG_BUILD_DIR}/tools/secure_header/sheader" "${STAGING_DIR_HOST}/bin/sheader"
    fi
  fi
  if [ -f "${PKG_BUILD_DIR}/tcboot/tcboot.bin" ]; then
    cpv "${PKG_BUILD_DIR}/tcboot/tcboot.bin" "${BIN_DIR}/tcboot.bin"
  fi
  if [ -f "${PKG_BUILD_DIR}/src/Uboot/${TCSUPPORT_UBOOT_VERSION}/env.bin" ]; then
    cpv "${PKG_BUILD_DIR}/src/Uboot/${TCSUPPORT_UBOOT_VERSION}/env.bin" "${BIN_DIR}/env.bin"
  fi
  echo "Install stage done. Artifacts in ${BIN_DIR}"
}

echo "==== tcboot build (en75xx) ===="
echo "SOC=${SOC}"
echo "TARGET_CROSS=${TARGET_CROSS}"
echo "RELEASE_SRC_PATH=${RELEASE_SRC_PATH}"
echo "PKG_BUILD_DIR=${PKG_BUILD_DIR}"
echo "MAKE_OPTS=${MAKE_OPTS}"

prepare_stage
compile_stage
install_stage

echo "==== build finished ===="