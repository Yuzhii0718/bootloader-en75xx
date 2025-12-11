#
# Copyright (c) 2015-2017, ARM Limited and Contributors. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

ECNT_PLAT		:=	plat/ecnt
ECNT_PLAT_SOC		:=	${ECNT_PLAT}/${PLAT}

PLAT_INCLUDES		:=	-I${ECNT_PLAT}/common/				\
				-I${ECNT_PLAT}/common/drivers/uart/		\
				-Iinclude/plat/arm/common/aarch64		\
				-I${ECNT_PLAT_SOC}/include/				\
				-Iinclude/plat/arm/common/

include lib/xlat_tables_v2/xlat_tables.mk

BL31_SOURCES+=	${XLAT_TABLES_LIB_SRCS}					\
				plat/arm/common/arm_gicv3.c				\
				plat/common/plat_gicv3.c				\
				drivers/arm/gic/common/gic_common.c		\
				drivers/arm/gic/v3/gicv3_main.c			\
				drivers/arm/gic/v3/gicv3_helpers.c		\
				drivers/console/aarch64/console.S		\
				drivers/delay_timer/delay_timer.c		\
				drivers/delay_timer/generic_delay_timer.c	\
				lib/cpus/aarch64/aem_generic.S			\
				lib/cpus/aarch64/cortex_a53.S			\
				${ECNT_PLAT}/common/ecnt_sip_svc.c		\
				${ECNT_PLAT}/common/drivers/uart/ecnt_uart.S	\
				${ECNT_PLAT}/common/drivers/efuse/efuse.c	\
				${ECNT_PLAT}/common/ecnt_plat_common.c		\
				${ECNT_PLAT_SOC}/aarch64/plat_helpers.S		\
				${ECNT_PLAT_SOC}/aarch64/platform_common.c	\
				${ECNT_PLAT_SOC}/bl31_plat_setup.c		\
				${ECNT_PLAT_SOC}/scu.c					\
				${ECNT_PLAT_SOC}/plat_topology.c			\
				${ECNT_PLAT_SOC}/plat_pm.c				\
				${ECNT_PLAT_SOC}/ecnt_trusted_boot.c



# Enable workarounds for selected Cortex-A53 erratas.
ERRATA_A53_835769	:=	1
#ERRATA_A53_843419	:=	1
ERRATA_A53_855873	:=	1

# indicate the reset vector address can be programmed
PROGRAMMABLE_RESET_ADDRESS	:=	1

#ECNT_SIP_KERNEL_BOOT_ENABLE := 1
#$(eval $(call add_define,ECNT_SIP_KERNEL_BOOT_ENABLE))

PLAT_XLAT_TABLES_DYNAMIC := 1
$(eval $(call add_define,PLAT_XLAT_TABLES_DYNAMIC))


ifneq ($(strip $(TCSUPPORT_UBOOT)),)
CONFIG_ECNT := 1
$(eval $(call add_define,CONFIG_ECNT))
endif

# Do not enable SVE
ENABLE_SVE_FOR_NS		:=	0

TRUSTED_BOARD_BOOT		:=	1
DYN_DISABLE_AUTH		:=	1
