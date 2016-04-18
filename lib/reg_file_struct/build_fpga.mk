include $(dir $(lastword $(MAKEFILE_LIST)))build_core.mk

$(VHDLS) += generic/rf1_generic.vhd
$(VHDLS) += generic/rf2_generic.vhd
$(VHDLS) += generic/rf4_generic.vhd
$(VHDLS) += generic/rf1_bw_generic.vhd
$(VHDLS) += generic/bist_config_generic.vhd
