all: $(BOARD_NAME).bin dt.dtb

CONFIG_CLK_CPU_DIVIDE ?= 16
CONFIG_CLK_MEM_2X_DIVIDE ?= 8

# Set config
include $(TOP_DIR)/soc_config.mk

include $(TOOLS_DIR)/soc.mk

boot.elf: force dt.S
	make -C $(TOP_DIR)/boot REVISION="$(REVISION)" EXTRA_CFLAGS="-I$(BOARD_DIR)" \
		DDR_TYPE=lpddr2 \
		CONFIG_GRLCD=0 \
		CONFIG_LCD_LOGO=0 \
		CONFIG_DEVTREE_FILENAME=forced.dtb \
		CONFIG_DEVTREE_ASM_FILE=$(OUTPUT_DIR)/dt.S \
		clean all
	cp "$(TOP_DIR)/boot/bin/boot.elf" .

# Set xilinx.mk variables
vhdlfiles := $(addprefix ../../,$(VHDL_FILES))
vhdlfiles += memory_fpga.vhd
vhdlfiles += config/config.vhd
vhdlfiles += $(wildcard $(BOARD_DIR)/*.vhd)

project = $(BOARD_NAME)
top_module = pad_ring
ucffile = $(BOARD_DIR)/constraints.ucf

flashsize = 16384
part = xc6slx25-2-csg324
part2 = xc6slx25-csg324-2

optfile = $(TOP_DIR)/xilinx.opt $(TOP_DIR)/withoutpads.opt
bitgen_opts := -g compress -g SPI_buswidth:1
promgen_opts = -spi

map_opts := -ol high -global_opt speed -pr b -w
par_opts := -ol high -xe n

include $(TOOLS_DIR)/xilinx.mk
