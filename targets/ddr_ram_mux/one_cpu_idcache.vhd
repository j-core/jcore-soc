use work.cache_pack.all;
use work.bus_mux_pkg.all;
use work.bus_mux_typec_pack.all;

-- Supports one cpu with icache. d-cache.
architecture one_cpu_idcache of ddr_ram_mux is
  signal instr_dbus_o : cpu_data_o_t;
  signal instr_dbus_i : cpu_data_i_t;
  signal data_dbus_o  : cpu_data_o_t;
  signal data_dbus_i  : cpu_data_i_t;
  signal cpu_ddr_bus_o : cpu_data_o_t;
  signal cpu_ddr_bus_i : cpu_data_i_t;
  signal instr_ddrburst : std_logic;
  signal data_ddrburst : std_logic;
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
      dbus_ddrburst => instr_ddrburst,
      dbus_i => instr_dbus_i);

  u_dcache : dcache_adapter
    port map (
      clk125 => clk,
      clk200 => clk_ddr,
      rst    => rst,
      ctrl   => dcache0_ctrl,
      ibus_o => cpu0_dbus_o,
      lock   => cpu0_mem_lock,
      ibus_i => cpu0_dbus_i,
      snpc_o => open,
      snpc_i => NULL_SNOOP_IO,
      dbus_o => data_dbus_o,
      dbus_lock => open,
      dbus_ddrburst => data_ddrburst,
      dbus_i => data_dbus_i);

  -- mux between instruction and data and dma : three masters
  u_bmuxc : bus_mux_typec port map (
  clk           => clk_ddr       ,
  rst           => rst           ,

  m1_o          => data_dbus_i   ,
  m1_ddrburst   => data_ddrburst ,
  m1_lock       => '0'            ,
  m1_i          => data_dbus_o   ,

  m2_o          => instr_dbus_i  ,
  m2_ddrburst   => instr_ddrburst ,
  m2_i          => instr_dbus_o  ,

  m3_o          => open          ,
  m3_ddrburst   => '0'           ,
  m3_lock       => '0'           ,
  m3_i          => NULL_DATA_O   ,

  m4_o          => open          ,
  m4_ddrburst   => '0'           ,
  m4_i          => NULL_DATA_O   ,

  m5_o          => dma_dbus_i    ,
  m5_i          => dma_dbus_o    ,
  mem_o         => ddr_bus_o     ,
  mem_ddrburst  => ddr_burst     ,
  mem_i         => ddr_bus_i     
      );

  -- terminate unused cpu1 buses
  cpu1_ibus_i <= loopback_bus(cpu1_ibus_o);
  cpu1_dbus_i <= loopback_bus(cpu1_dbus_o);
end architecture;
