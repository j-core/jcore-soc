# Used for simulation. See other build_asic.mk and build_fpga.mk for
# files included in those builds.

include $(dir $(lastword $(MAKEFILE_LIST)))build_core.mk

$(VHDLS) += ram_18x2048_1rw.vhd
$(VHDLS) += ram_2x8x256_1rw.vhd
$(VHDLS) += ram_32x1x512_2rw.vhd
$(VHDLS) += ram_2x8x2048_2rw.vhd
$(VHDLS) += rom_32x2048_1r.vhd

$(VHDLS) += ram_1rw_mems.vhd
$(VHDLS) += ram_2rw_mems.vhd
$(VHDLS) += rom_1r_mems.vhd

$(VHDLS) += tech/inferred/rom_1r_infer.vhd
$(VHDLS) += tech/inferred/ram_1rw_infer.vhd
$(VHDLS) += tech/inferred/ram_2rw_infer.vhd

# These aren't used by anything.
# TODO: consider removing them from the memory_pkg.vhd
#$(VHDLS) += tech/inferred/ram_32x32.vhd
#$(VHDLS) += tech/inferred/ram_32x2048.vhd
