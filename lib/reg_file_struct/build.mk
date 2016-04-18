include $(dir $(lastword $(MAKEFILE_LIST)))build_core.mk

GENERIC += generic/rf1_generic.vhd
GENERIC += generic/rf2_generic.vhd
GENERIC += generic/rf4_generic.vhd
GENERIC += generic/rf1_bw_generic.vhd
GENERIC += generic/bist_config_generic.vhd

$(VHDLS) += $(GENERIC)
