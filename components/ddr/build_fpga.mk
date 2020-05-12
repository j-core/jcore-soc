include $(dir $(lastword $(MAKEFILE_LIST)))build.mk
$(VHDLS) += ddr_iocells.vhd
$(VHDLS) += ddr_iocells_k7.vhd
