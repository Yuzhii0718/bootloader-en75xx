/*
 * Copyright (c) 2015-2016, ARM Limited and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include <errno.h>
#include <assert.h>
#include <stdio.h>

#include <platform_def.h>

#include <arch.h>
#include <arch_helpers.h>
#include <drivers/generic_delay_timer.h>
#include <drivers/console.h>
#include <lib/mmio.h>
#include <tools_share/firmware_image_package.h>
#include <common/desc_image_load.h>
#include <common/image_decompress.h>

#include <lib/xlat_tables/xlat_tables_v2.h>

#include <LzmaTools.h>

#include <plat/common/platform.h>
#include <plat_private.h>
#include <flashhal.h>
#include <xmodem.h>

/* Data structure which holds the extents of the trusted SRAM for BL1*/
static meminfo_t bl2_el3_tzram_layout;
static console_t console;
static hw_trap_t hw_trap;
static int debug_flag = 0;

unsigned int bl31_base_addr = BL31_BASE;
unsigned int rst_vector_base_addr = RVBADDRESS_CPU0;

extern int console_ecnt_register(uintptr_t baseaddr, console_t *console);
extern int XModemReceive(console_t *console, unsigned int bufLen , unsigned char *bufBase);
extern void	get_bootimage_by_npu_iNIC(unsigned int imgDstAddr);
extern void disable_NPU_dbgMsg(void);
extern void phy_config_efuse_load(void);
#ifdef CPU_BUS_BL2_TEST
extern void tests_on_l2c_sram(void);
#endif

void hw_trap_init(void)
{
	int mode = 0;

	if (debug_flag)
	{
		mode = mmio_read_32(EN7523_SCREG_WF0);

		switch (mode)
		{
			case DBG_INIC_MODE:
			{
				hw_trap.inc_mode = 1;
				hw_trap.fw_upgrade_mode = 0;
				hw_trap.skip_fw_upgrade = 0;
				NOTICE("DBG_INIC_MODE\n");
				break;
			}
			case DBG_FWU_MODE:
			{
				hw_trap.inc_mode = 0;
				hw_trap.fw_upgrade_mode = 1;
				hw_trap.skip_fw_upgrade = 0;
				NOTICE("DBG_FWU_MODE\n");
				break;
			}
			case DBG_FLASH_MODE:
			{
				hw_trap.inc_mode = 0;
				hw_trap.fw_upgrade_mode = 0;
				hw_trap.skip_fw_upgrade = 0;
				NOTICE("DBG_FLASH_MODE\n");
				break;
			}
			default:
				NOTICE("Unknow Debug mode\n");
		}
	}
	else
	{
		hw_trap.skip_fw_upgrade	= !(mmio_read_32(EN7523_SEC_SSR) & BOOT_SEL_BY_HWTRAP);
		hw_trap.fw_upgrade_mode	= !(mmio_read_32(EN7523_HWTRAP_CONF) & HWTRAP_FW_UPGRADE);
		hw_trap.inc_mode 		= ((mmio_read_32(EN7523_HWTRAP_CONF) & 0x7) == HWTRAP_INIC_MODE);
	}

	hw_trap.hw_trap_decode	= (mmio_read_32(EN7523_HWTRAP_DEC) & 0x2f);
}

void debug_init(void)
{
	if (((mmio_read_32(EN7523_HWTRAP_CONF) & 0x7) == 0)	||
		((mmio_read_32(EN7523_HWTRAP_CONF) & 0x7) == 1) ||
		((mmio_read_32(EN7523_HWTRAP_CONF) & 0x7) == 3))
	{
		if (mmio_read_32(EN7523_SCREG_WF1) == DEBUG_MAGIC)
		{
			debug_flag = 1;
			tf_log_set_max_level(LOG_LEVEL_NOTICE);
			return;
		}
	}

	tf_log_set_max_level(LOG_LEVEL_ERROR);
}

void __dead2 plat_error_handler(int err)
{
	mmio_write_32(EN7523_SCREG_WF0, err);
	while (1)
		wfi();
}

meminfo_t *bl2_plat_sec_mem_layout(void)
{
	return &bl2_el3_tzram_layout;
}

/*******************************************************************************
 * Perform any BL2 specific platform actions.
 ******************************************************************************/
void bl2_el3_early_platform_setup(u_register_t arg1, u_register_t arg2,
			u_register_t arg3, u_register_t arg4)
{
	/* Initialize the console to provide early debug support */
	console_ecnt_register(EN7523_UART0_BASE, &console);
	debug_init();
	efuse_init();
	phy_config_efuse_load();
	/*
	 * Allow BL2 to see the whole Trusted RAM.
	 */
	bl2_el3_tzram_layout.total_base = BL_SRAM_BASE;
	bl2_el3_tzram_layout.total_size = BL_SRAM_SIZE;
}

/******************************************************************************
 * Perform the very early platform specific architecture setup.  This only
 * does basic initialization. Later architectural setup (bl1_arch_setup())
 * does not do anything platform specific.
 *****************************************************************************/

void bl2_el3_plat_arch_setup(void)
{
	unsigned int dram_size = 0;

	write_cntfrq_el0(plat_get_syscnt_freq2());
	generic_delay_timer_init();

	ecnt_system_init(&dram_size);
    #ifdef CPU_BUS_BL2_TEST   
    tests_on_l2c_sram();
    #endif

	mmap_add_region(EN7523_MEM_BASE, EN7523_MEM_BASE, dram_size, MT_DEVICE | MT_RW | MT_SECURE);
    plat_configure_mmu_svc_mon(bl2_el3_tzram_layout.total_base,
                   bl2_el3_tzram_layout.total_size,
                   BL_CODE_BASE,
                   BL2_CODE_END,
                   BL_COHERENT_RAM_BASE,
                   BL_COHERENT_RAM_END);
}

void bl2_el3_plat_prepare_exit(void)
{
	jumparch64(BL33_BASE, 0, 0, TZRAM_BASE);
	panic();
}

void bl2_close_lan_led_hw_lighting(void)
{
	unsigned int reg = 0x0;
	reg = mmio_read_32(0x1FA20224);
	reg |= (0xf<<22);
	mmio_write_32(0x1FA20224, reg);
}

void bl2_plat_preload_setup(void)
{
	image_decompress_init(EN7523_IMAGE_BUF_OFFSET, EN7523_IMAGE_BUF_SIZE, lzmaBuffToBuffDecompress);
	bl2_platform_setup();
	bl2_close_lan_led_hw_lighting();
#ifdef INC_MODE
	if (hw_trap.inc_mode)
	{

		get_bootimage_by_npu_iNIC((unsigned int) PLAT_ECNT_FIP_BASE);
	}
	else
#endif
	{
		if (hw_trap.fw_upgrade_mode && !(hw_trap.skip_fw_upgrade))
		{
			int len = 0;

			if (flash_read(PLAT_ECNT_FIP_OFFSET, PLAT_ECNT_FIP_MAX_SIZE, (uint8_t *) PLAT_ECNT_FIP_BASE) != FLASH_READ_STATUS_CORRECT)
			{
				panic();
			}

			if (plat_check_bypass() != BYPASS_FWUPGRADE)
			{
				printf("Press x to update firmware\n");
				while (len == 0)
				{
					if (console.getc(&console) == 'x')
					{
						len = XModemReceive(&console, (PLAT_ECNT_FIP_MAX_SIZE + PLAT_ECNT_MV_DATA_SIZE),
									(uint8_t *) (PLAT_ECNT_FIP_BASE - PLAT_ECNT_MV_DATA_SIZE));
					}
				}

				if (len == (PLAT_ECNT_FIP_MAX_SIZE + PLAT_ECNT_MV_DATA_SIZE))
				{
					flash_erase(0, len);
					flash_write(0, len, (uint8_t *) (PLAT_ECNT_FIP_BASE - PLAT_ECNT_MV_DATA_SIZE));
				}
			}
			else
			{
				NOTICE("BYPASS\n");
			}
		}
		else
		{
			if (flash_read(PLAT_ECNT_FIP_OFFSET, PLAT_ECNT_FIP_MAX_SIZE, (uint8_t *) PLAT_ECNT_FIP_BASE) == FLASH_READ_STATUS_CORRECT)
			{
			}
			else
			{
				panic();
			}
		}
	}

	while (plat_check_header((uint8_t *) PLAT_ECNT_FIP_BASE) == 0)
	{
#ifdef INC_MODE
		if (get_into_inic())
		{
			get_bootimage_by_npu_iNIC((unsigned int) PLAT_ECNT_FIP_BASE);
		}
		else
#endif
		{
			panic();
		}
	}
}

void bl2_platform_setup(void)
{
	hw_trap_init();
	flash_init();
	plat_ecnt_io_setup();
}

int bl2_plat_handle_post_image_load(unsigned int image_id)
{
	bl_mem_params_node_t *bl_mem_params = get_bl_mem_params_node(image_id);

	if (!(bl_mem_params->image_info.h.attr & IMAGE_ATTRIB_SKIP_LOADING))
	{
		if (image_decompress(&(bl_mem_params->image_info)))
		{
			panic();
		}
	}

	return 0;
}

int bl2_plat_handle_pre_image_load(unsigned int image_id)
{
	bl_mem_params_node_t *bl_mem_params = get_bl_mem_params_node(image_id);

	image_decompress_prepare(&(bl_mem_params->image_info));

	return 0;
}
