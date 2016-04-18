use work.bus_mux_pkg.all;

-- Supports one CPU with no caching or DMA.
architecture one_cpu_direct of ddr_ram_mux is
  signal instr_dbus_o : cpu_data_o_t;
  signal instr_dbus_i : cpu_data_i_t;
begin
  splice_instr_data_bus(cpu0_ibus_o, cpu0_ibus_i, instr_dbus_o, instr_dbus_i);

  -- combine the instruction and data DDR buses
  u_bmux : multi_master_bus_mux port map(
    rst => rst,
    clk => clk,
    m1_i => cpu0_dbus_i,  m1_o => cpu0_dbus_o,
    m2_i => instr_dbus_i, m2_o => instr_dbus_o,
    slave_i => ddr_bus_i, slave_o => ddr_bus_o);

  -- terminate unused buses
  cpu1_ibus_i <= loopback_bus(cpu1_ibus_o);
  cpu1_dbus_i <= loopback_bus(cpu1_dbus_o);
  dma_dbus_i  <= loopback_bus(dma_dbus_o);
  ddr_burst <= '0';
end architecture;
