# Default configration values. These can be overridden for each
# board in the board's Makefile.
#
# The settings in this file go into the config.h and config.vhd
# generated during each build (in the config/ subdirectory of the
# build's output directory). To be included properly, the variable
# names must begin with CONFIG_ and the values should be valid as the
# value for a VHDL integer constant.
#
# TODO: tools/soc.mk gathers these config values together with
#   CONF_VARS:=$(sort $(filter CONFIG_%,$(.VARIABLES)))
# This could grab values from the environment which would not be
# appropriate for VHDL integers and cause the build to fail. Should
# explicitly list the CONFIG_ var names instead?

# The clkin25 PLL VCO frequency is 1GHz. These *_DIVIDE settings set
# the frequency of the clk_cpu and clk_mem_2x clocks by controller how
# much to divide down from 1GHz.

# SA_WIDTH and DDRDQ_WIDTH are needed for components/ddr
CONFIG_SA_WIDTH = 13
CONFIG_DDRDQ_WIDTH = 16

# 1GHz / 20 = 50MHz
CONFIG_CLK_CPU_DIVIDE = 20
# 1GHz / 10 = 100MHz
CONFIG_CLK_MEM_2X_DIVIDE = 10

# Because PLL VCO is 1GHz, the divide setting is also the period in
# ns.
CONFIG_CLK_CPU_PERIOD_NS = $(CONFIG_CLK_CPU_DIVIDE)
CONFIG_CLK_MEM_PERIOD_NS = $(shell echo $$(( 2 * $(CONFIG_CLK_MEM_2X_DIVIDE) )) )
CONFIG_CLK_BITLINK_PERIOD_NS = 8

# generic of components/ddr2/ddrc_phy.vhd
# Correct value depends on clk_mem frequency
# TODO: Set automatically?
CONFIG_DDR_READ_SAMPLE_TM =  2

#CONFIG_BUS_PERIOD = 40

# ddr2/ddrc_cnt_pkg.vhd
CONFIG_DDR_CK_CYCLE = $(CONFIG_CLK_MEM_PERIOD_NS)
