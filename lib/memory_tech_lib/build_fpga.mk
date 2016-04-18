include $(dir $(lastword $(MAKEFILE_LIST)))build_core.mk

$(VHDLS) += tech/inferred/rom_1r_infer.vhd
$(VHDLS) += tech/inferred/ram_1rw_infer.vhd
$(VHDLS) += tech/inferred/ram_2rw_infer.vhd
