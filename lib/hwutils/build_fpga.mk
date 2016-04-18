include $(dir $(lastword $(MAKEFILE_LIST)))build.mk
$(VHDLS) += ddr_input_fpga.vhd
$(VHDLS) += ddr_output_fpga.vhd
$(VHDLS) += clock_output_fpga.vhd
$(VHDLS) += global_buffer_fpga.vhd
