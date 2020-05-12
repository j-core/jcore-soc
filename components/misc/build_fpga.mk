include $(dir $(lastword $(MAKEFILE_LIST)))build.mk
#$(VHDLS) += fpga_ctrl.vhd
$(VHDLS) += fpga_reboot.vhd
