configuration ddr_ram_mux_one_cpu_idcache_fpga of ddr_ram_mux is
  for one_cpu_idcache
    for all : icache_adapter
      use configuration work.icache_adapter_fpga;
    end for;
    for all : dcache_adapter
      use configuration work.dcache_adapter_fpga;
    end for;
  end for;
end configuration;
