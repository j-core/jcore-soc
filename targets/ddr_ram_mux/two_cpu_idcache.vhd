use work.cache_pack.all;
use work.bus_mux_pkg.all;
use work.bus_mux_lock_pkg.all;
use work.bus_mux_typec_pack.all;

-- Supports two cpus with icache. d-cache.
architecture two_cpu_idcache of ddr_ram_mux is
  signal instr0_dbus_o : cpu_data_o_t;
  signal instr0_dbus_i : cpu_data_i_t;
  signal data0_dbus_o  : cpu_data_o_t;
  signal data0_dbus_i  : cpu_data_i_t;
  signal data0_dbus_lock  : std_logic;
  signal instr1_dbus_o : cpu_data_o_t;
  signal instr1_dbus_i : cpu_data_i_t;
  signal data1_dbus_o  : cpu_data_o_t;
  signal data1_dbus_i  : cpu_data_i_t;
  signal data1_dbus_lock  : std_logic;
--  signal cpu_ddr_bus_o : cpu_data_o_t;
--  signal cpu_ddr_bus_i : cpu_data_i_t;
--  signal cpu_instr_ddr_bus_o : cpu_data_o_t;
--  signal cpu_instr_ddr_bus_i : cpu_data_i_t;
--  signal cpu_data_ddr_bus_o : cpu_data_o_t;
--  signal cpu_data_ddr_bus_i : cpu_data_i_t;
  signal instr0_ddrburst : std_logic;
  signal instr1_ddrburst : std_logic;
  signal data0_ddrburst : std_logic;
  signal data1_ddrburst : std_logic;
  signal cache0_snoop  : dcache_snoop_io_t;
  signal cache1_snoop  : dcache_snoop_io_t;
begin
  u_icache0 : icache_adapter
    port map (
      clk125 => clk,
      clk200 => clk_ddr,
      rst    => rst,
      ctrl   => icache0_ctrl,
      ibus_o => cpu0_ibus_o,
      ibus_i => cpu0_ibus_i,
      dbus_o => instr0_dbus_o,
      dbus_ddrburst => instr0_ddrburst,
      dbus_i => instr0_dbus_i);

  u_icache1 : icache_adapter
    port map (
      clk125 => clk,
      clk200 => clk_ddr,
      rst    => rst,
      ctrl   => icache1_ctrl,
      ibus_o => cpu1_ibus_o,
      ibus_i => cpu1_ibus_i,
      dbus_o => instr1_dbus_o,
      dbus_ddrburst => instr1_ddrburst,
      dbus_i => instr1_dbus_i);

  u_dcache0 : dcache_adapter
    port map (
      clk125 => clk,
      clk200 => clk_ddr,
      rst    => rst,
      ctrl   => dcache0_ctrl,
      ibus_o => cpu0_dbus_o,
      lock   => cpu0_mem_lock,
      ibus_i => cpu0_dbus_i,
      snpc_o => cache0_snoop,
      snpc_i => cache1_snoop,
      dbus_o    => data0_dbus_o,
      dbus_lock => data0_dbus_lock,
      dbus_ddrburst => data0_ddrburst,
      dbus_i    => data0_dbus_i);

  u_dcache1 : dcache_adapter
    port map (
      clk125 => clk,
      clk200 => clk_ddr,
      rst    => rst,
      ctrl   => dcache1_ctrl,
      ibus_o => cpu1_dbus_o,
      lock   => cpu1_mem_lock,
      ibus_i => cpu1_dbus_i,
      snpc_o => cache1_snoop,
      snpc_i => cache0_snoop,
      dbus_o    => data1_dbus_o,
      dbus_lock => data1_dbus_lock,
      dbus_ddrburst => data1_ddrburst,
      dbus_i    => data1_dbus_i);

  -- mux between instruction and data and dma : three masters
  u_bmuxc : bus_mux_typec port map (
  clk           => clk_ddr       ,
  rst           => rst           ,

  m1_o          => data0_dbus_i   ,
  m1_ddrburst   => data0_ddrburst ,
  m1_lock       => data0_dbus_lock,
  m1_i          => data0_dbus_o   ,

  m2_o          => instr0_dbus_i  ,
  m2_ddrburst   => instr0_ddrburst ,
  m2_i          => instr0_dbus_o  ,

  m3_o          => data1_dbus_i   ,
  m3_ddrburst   => data1_ddrburst ,
  m3_lock       => data1_dbus_lock,
  m3_i          => data1_dbus_o   ,

  m4_o          => instr1_dbus_i  ,
  m4_ddrburst   => instr1_ddrburst ,
  m4_i          => instr1_dbus_o  ,

  m5_o          => dma_dbus_i    ,
  m5_i          => dma_dbus_o    ,
  mem_o         => ddr_bus_o     ,
  mem_ddrburst  => ddr_burst     ,
  mem_i         => ddr_bus_i     
      );
end architecture;
