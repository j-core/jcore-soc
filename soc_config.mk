# Default configration values. These can be overridden for each
# board in the board's Makefile.
#
# This method of configuration is somewhat outdated. It was brought
# over from mcu_lib. Some of the things these options control, like
# the inclusion of a device or the number of devices in the design is
# now controlled by soc_gen. Overtime, we will remove the config
# options from here that are no longer used.

CONFIG_BUS_PERIOD = 40
CONFIG_SA_WIDTH = 13
CONFIG_DDRDQ_WIDTH = 16
CONFIG_MEM_ADDR_WIDTH = 14
