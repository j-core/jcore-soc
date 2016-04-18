configuration ddr_ram_mux_one_cpu_icache_fpga of ddr_ram_mux is
  for one_cpu_icache
    for all : icache_adapter
      use configuration work.icache_adapter_fpga;
    end for;
  end for;
end configuration;
