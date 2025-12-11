#
# Copyright (C) 2010-2013 airoha.com
#
# AIROHA Property Software.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk
include $(INCLUDE_DIR)/target.mk
-include $(INCLUDE_DIR)/ecnt-release.mk
include release_sdk.mk

PKG_NAME:=tcboot
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(KERNEL_BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/tcboot
  SECTION:=Econet Properties
  CATEGORY:=Econet Properties
  TITLE:=tcboot for econt
  SUBMENU:=tcboot
endef

define Package/tcboot/description
 	This package contains bootloader code.
endef

#TARGET_CFLAGS += $(TC_CFLAGS)
#TARGET_CFLAGS += -D_GNU_SOURCE

ifneq ($(strip $(TCSUPPORT_CPU_EN7523)),)
ifneq ($(strip $(TCSUPPORT_CPU_EN7581)),)
export UBOOT_CONFIG=an7581
export TOOLCHAIN_BASE=/opt/trendchip/buildroot-gcc1030-glibc232_kernel5_4/usr
endif
MAKE_OPTS:= \
	CROSS_COMPILE="$(TARGET_CROSS)" \
	#SUBDIRS="$(PKG_BUILD_DIR)"
ifeq ($(REBUILDCODE),)
	MAKE_OPTS+=TCSUPPORT_OPENWRT_RELEASECODE=$(RELSASED_SDK)
else
	MAKE_OPTS+=TCSUPPORT_OPENWRT_RELEASECODE=""
endif
UNOPEN_IMG_PATH=unopen_img/$(RELEASE_SRC_PATH)/atf
else
MAKE_OPTS:= \
	ARCH="$(LINUX_KARCH)" \
	CROSS_COMPILE="$(TARGET_CROSS)" \
	SUBDIRS="$(PKG_BUILD_DIR)" \
	TCSUPPORT_OPENWRT_RELEASE_SRC_PATH=$(RELEASE_SRC_PATH) \
#	EXTRA_CFLAGS+=-Wno-error=date-time
ifeq ($(RELEASECODE),)
	MAKE_OPTS+=TC_BUILD_RELEASECODE=1
endif
endif
	
MAKE_FLAGS+= \
	SUBDIRS="$(PKG_BUILD_DIR)"


define Build/EcntPrepare

ifneq ($(strip $(TCSUPPORT_CPU_EN7523)),)
	rm -rf ./tools
	
	$(INSTALL_DIR) ./tools
	
	$(CP) -rf $(TRUNK_DIR)/bootloader ./
	
	make -C $(TRUNK_DIR)/tools/lzma432/7zip/Compress/LZMA_Alone/ clean
	make -C $(TRUNK_DIR)/tools/lzma432/7zip/Compress/LZMA_Alone/
	$(CP) $(TRUNK_DIR)/tools/lzma432/7zip/Compress/LZMA_Alone/lzma ./tools
	
	make -C $(TRUNK_DIR)/tools/trx clean
	make -C $(TRUNK_DIR)/tools/trx
	$(CP) $(TRUNK_DIR)/tools/trx ./tools
ifneq ($(strip $(TCSUPPORT_BL2_OPTIMIZATION)),)
	$(CP) $(TRUNK_DIR)/tools/flash_table ./tools/
endif	
else
	rm -rf ./bootrom
	rm -rf ./tools
	rm -rf ./version
	$(INSTALL_DIR) ./bootrom
	$(INSTALL_DIR) ./tools
	$(INSTALL_DIR) ./version
	$(CP) $(TRUNK_DIR)/bootrom/* ./bootrom
	$(CP) $(TRUNK_DIR)/bootrom/openwrt/* ./bootrom
	$(CP) $(TRUNK_DIR)/tools/lzma ./tools
	$(CP) $(TRUNK_DIR)/tools/trx ./tools
	$(CP) $(TRUNK_DIR)/tools/secure_header ./tools
	$(CP) $(TRUNK_DIR)/tools/mbedtls-2.5.1 ./tools
endif
endef


define Build/Prepare
	$(if $(REBUILDCODE),$(call Build/EcntPrepare))
	mkdir -p $(PKG_BUILD_DIR)
ifneq ($(strip $(TCSUPPORT_CPU_EN7523)),)
ifneq ($(strip $(TCSUPPORT_ARM_SECURE_BOOT)),)
	mkdir -p $(BSP_EXT_TCLINUX_BUILDER)
	chmod 777 -R $(shell pwd)/bootloader/ATF/openssl
endif
	cp -rf $(shell pwd)/bootloader $(PKG_BUILD_DIR)/src 
else
	cp -rf $(shell pwd)/bootrom $(PKG_BUILD_DIR)/src 
	chmod 755 $(PKG_BUILD_DIR)/src/byteswap
	cp -rf $(shell pwd)/version $(PKG_BUILD_DIR)/
endif
	cp -rf $(shell pwd)/tools $(PKG_BUILD_DIR)/
	chmod 777 -R $(PKG_BUILD_DIR)/tools
	if [ -f $(shell pwd)/tcboot/tcboot.bin ]; then \
		cp -rf $(shell pwd)/tcboot $(PKG_BUILD_DIR)/; \
	fi
endef

define Build/BootRelease

ifneq ($(strip $(TCSUPPORT_CPU_EN7523)),)
	mkdir -p $(shell pwd)/bootloader/$(UNOPEN_IMG_PATH)
	$(CP) $(PKG_BUILD_DIR)/src/$(UNOPEN_IMG_PATH)/* $(shell pwd)/bootloader/$(UNOPEN_IMG_PATH)/
	$(MAKE) -C $(shell pwd)/bootloader -f make_bootbase ATF_DIR=$(shell pwd)/bootloader/ATF $(MAKE_OPTS) delete_code
	@echo "RELSASED_SDK=1" > release_sdk.mk
else
	$(CP) $(PKG_BUILD_DIR)/src/unopen_img/$(RELEASE_SRC_PATH) ./bootrom/unopen_img/
ifneq ($(strip $(TCSUPPORT_CPU_EN7580)),)
	mkdir -p ./bootrom/unopen_img/$(RELEASE_SRC_PATH)/ram_init/output
	$(CP) $(PKG_BUILD_DIR)/src/ram_init/output/* ./bootrom/unopen_img/$(RELEASE_SRC_PATH)/ram_init/output/
	$(CP) $(PKG_BUILD_DIR)/src/ram_init/spram.c ./bootrom/unopen_img/$(RELEASE_SRC_PATH)/ram_init/
	$(CP) $(PKG_BUILD_DIR)/src/spram_ext/system.o ./bootrom/unopen_img/$(RELEASE_SRC_PATH)/ram_init/output/
else
ifneq ($(strip $(TCSUPPORT_CPU_EN7512) $(TCSUPPORT_CPU_EN7521)),)
	mkdir -p ./bootrom/unopen_img/$(RELEASE_SRC_PATH)/ddr_cal_en7512/output
	$(CP) $(PKG_BUILD_DIR)/src/ddr_cal_en7512/output/* ./bootrom/unopen_img/$(RELEASE_SRC_PATH)/ddr_cal_en7512/output/
	$(CP) $(PKG_BUILD_DIR)/src/ddr_cal_en7512/spram.c ./bootrom/unopen_img/$(RELEASE_SRC_PATH)/ddr_cal_en7512/
	$(CP) $(PKG_BUILD_DIR)/src/spram_ext/system.o ./bootrom/unopen_img/$(RELEASE_SRC_PATH)/ddr_cal_en7512/output/
else
ifneq ($(strip $(TCSUPPORT_CPU_MT7510) $(TCSUPPORT_CPU_MT7520)),)
	mkdir -p ./bootrom/ddr_cal/reserved
	$(CP) $(PKG_BUILD_DIR)/src/ddr_cal/output/* ./bootrom/ddr_cal/reserved/
	$(CP) $(PKG_BUILD_DIR)/src/ddr_cal/spram.c ./bootrom/ddr_cal/reserved/
else
ifneq ($(strip $(TCSUPPORT_CPU_MT7505)),)
	mkdir -p ./bootrom/ddr_cal_mt7505/reserved
	$(CP) $(PKG_BUILD_DIR)/src/ddr_cal_mt7505/output/* ./bootrom/ddr_cal_mt7505/reserved/
	$(CP) $(PKG_BUILD_DIR)/src/ddr_cal_mt7505/spram.c ./bootrom/ddr_cal_mt7505/reserved/
endif
endif
endif
endif
endif
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR)/src -f make_bootbase $(MAKE_OPTS) bootbase TCPLATFORM=$(RELEASE_SRC_PATH)\
	BSP_ROOTDIR=$(ECNT_BUILD_DIR) \
	KERNEL_DIR:=$(LINUX_DIR)
	$(if $(RELEASECODE),$(call Build/BootRelease))
ifneq ($(CONFIG_TARGET_econet_en7580),)
ifneq ($(RELEASECODE),)
	+$(MAKE_VARS) \
	$(MAKE) -C $(shell pwd)/ -f $(shell pwd)/openwrt_release OPENWRT_PWD=$(PKG_BUILD_DIR)  BOOTROM_DIR=`pwd`/bootrom/ \
	release_boot
endif
endif
	$(if $(RELEASECODE),$(call EcntModules/release_feeds))
endef

define Package/tcboot/install
		$(CP) $(PKG_BUILD_DIR)/src/tcboot.bin $(BIN_DIR)
		$(CP) $(PKG_BUILD_DIR)/src/bootext.ram $(BIN_DIR)
		$(CP) $(PKG_BUILD_DIR)/src/Uboot/u-boot-2014.04-rc1/u-boot.bin $(BIN_DIR)
ifneq ($(strip $(TCSUPPORT_SECURE_BOOT)),)
		$(CP) $(PKG_BUILD_DIR)/tools/secure_header/sheader $(STAGING_DIR_HOST)/bin/
endif
		if [ -f $(PKG_BUILD_DIR)/tcboot/tcboot.bin ]; then \
			$(CP) $(PKG_BUILD_DIR)/tcboot/tcboot.bin $(BIN_DIR); \
		fi
		$(CP) $(PKG_BUILD_DIR)/src/Uboot/u-boot-2014.04-rc1/env.bin $(BIN_DIR)
endef

$(eval $(call BuildPackage,tcboot))
