CC = gcc
FLASH_INC = -I $(GLOBAL_INC_DIR)/modules
ifneq ($(strip $(RDKB_BUILD)),)
CFLAGS := 
endif
CFLAGS += -fPIC -O2 -DFLASH_TABLE_OPEN -DTCSUPPORT_BL2_OPTIMIZATION

#ifneq ($(TCSUPPORT_PARALLEL_NAND),)
#FLASH_TABLE_SRC += $(KERNEL_EXT_SPI_NAND_DIR)/parallel_nand_flash_table.c
#CFLAGS += -DTCSUPPORT_PARALLEL_NAND
#endif

LDFLAGS = -L../ -lm
ifneq ($(strip $(RDKB_BUILD)),)
FLASH_TABLE_SRC += spi_nand_flash_table.c
else
FLASH_TABLE_SRC += $(KERNEL_EXT_SPI_NAND_DIR)/spi_nand_flash_table.c
endif

.SUFFIXES:  .c .o

.c.o:
	$(CC) $(CFLAGS) $(LDFLAGS) -c $<

test: $(FLASH_TABLE_SRC)
	$(CC) $(CFLAGS) $(FLASH_INC) $(FLASH_TABLE_SRC) -o $@ $(LDFLAGS)
