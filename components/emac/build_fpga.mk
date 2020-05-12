include $(dir $(lastword $(MAKEFILE_LIST)))build.mk
$(VHDLS) += eth_mac_rmii_fpga.vhd
