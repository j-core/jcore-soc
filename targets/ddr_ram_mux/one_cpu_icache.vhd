use work.cache_pack.all;
use work.bus_mux_pkg.all;

-- Supports one cpu with icache. No d-cache.
architecture one_cpu_icache of ddr_ram_mux is
  signal instr_dbus_o : cpu_data_o_t;
  signal instr_dbus_i : cpu_data_i_t;
  signal cpu_ddr_bus_o : cpu_data_o_t;
  signal cpu_ddr_bus_i : cpu_data_i_t;
begin
  u_icache : icache_adapter
    port map (
      clk125 => clk,
      clk200 => clk_ddr,
      rst    => rst,
      ctrl   => icache0_ctrl,
      ibus_o => cpu0_ibus_o,
      ibus_i => cpu0_ibus_i,
      dbus_o => instr_dbus_o,
      dbus_i => instr_dbus_i);

  -- combine the instruction and data DDR buses
  u_bmux : multi_master_bus_mux port map(
    rst => rst,
    clk => clk,
    m1_i => cpu0_dbus_i,  m1_o => cpu0_dbus_o,
    m2_i => instr_dbus_i, m2_o => instr_dbus_o,
    slave_i => cpu_ddr_bus_i, slave_o => cpu_ddr_bus_o);

  -- mux between cpu(i&d) and dma
--  u_bmuxb : bus_mux_typeb port map(
--    clk    => clk,
--    rst    => rst,
--    m1_o   => cpu_ddr_bus_i,
--    m1_i   => cpu_ddr_bus_o,
--    m2_o   => dma_dbus_i,
--    m2_i   => dma_dbus_o,
--    mem_o  => ddr_bus_o,
--    mem_i  => ddr_bus_i);

  -- terminate unused cpu1 buses
  cpu1_ibus_i <= loopback_bus(cpu1_ibus_o);
  cpu1_dbus_i <= loopback_bus(cpu1_dbus_o);
  dma_dbus_i  <= loopback_bus(dma_dbus_o);
  ddr_burst <= '0';
end architecture;
