LX=9

all: $(BOARD_NAME)$(LX).bit $(BOARD_NAME)$(LX).mcs

# Set config
include $(TOP_DIR)/soc_config.mk
CONFIG_BUS_PERIOD = 32
CONFIG_SA_WIDTH = 13

include $(TOOLS_DIR)/soc.mk

boot.elf: force
	make -C $(TOP_DIR)/boot DDR_TYPE=lpddr REVISION="$(REVISION)" CONFIG_GRLCD=0 CONFIG_LCD_LOGO=0 CONFIG_LOAD_ELF=1 clean all
	cp "$(TOP_DIR)/boot/bin/boot.elf" .

# Set xilinx.mk variables
vhdlfiles := $(addprefix ../../,$(VHDL_FILES))
vhdlfiles += memory_fpga.vhd
vhdlfiles += config/config.vhd
vhdlfiles += $(wildcard $(BOARD_DIR)/*.vhd)

project = $(BOARD_NAME)$(LX)
top_module = pad_ring
ucffile = $(BOARD_DIR)/constraints.ucf

flashsize = 16384
part = xc6slx$(LX)-2-csg324
part2 = xc6slx$(LX)-csg324-2

optfile = $(TOP_DIR)/xilinx.opt $(TOP_DIR)/withoutpads.opt
bitgen_opts := -g compress -g SPI_buswidth:1
promgen_opts = -spi

ifeq ($(ISE_VERSION),13.1)
map_opts := -ol high -w
par_opts := -ol high
endif
ifeq ($(ISE_VERSION),14.6)
map_opts := -ol high -xe n -logic_opt on -t 2
par_opts := -ol high -xe n
endif
ifeq ($(ISE_VERSION),14.7)
map_opts := -ol high -xe n -logic_opt on -t 2
par_opts := -ol high -xe n
endif

include $(TOOLS_DIR)/xilinx.mk
