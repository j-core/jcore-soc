include $(dir $(lastword $(MAKEFILE_LIST)))build.mk
$(VHDLS) += cpus_one.vhd
$(VHDLS) += cpus_two_fpga.vhd
$(VHDLS) += ddr_ram_mux/one_cpu_direct.vhd
$(VHDLS) += ddr_ram_mux/one_cpu_icache.vhd
$(VHDLS) += ddr_ram_mux/one_cpu_icache_fpga.vhd
$(VHDLS) += ddr_ram_mux/one_cpu_idcache.vhd
$(VHDLS) += ddr_ram_mux/one_cpu_idcache_fpga.vhd
$(VHDLS) += ddr_ram_mux/two_cpu_idcache.vhd
$(VHDLS) += ddr_ram_mux/two_cpu_idcache_fpga.vhd
