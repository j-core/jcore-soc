use work.bus_mux_pkg.all;
use work.cpu_prefetch_pack.all;

-- Supports one CPU with a prefetcher on instructions. No d-cache or dma.
architecture one_cpu_prefetch of ddr_ram_mux is
  signal instr_dbus_o : cpu_data_o_t;
  signal instr_dbus_i : cpu_data_i_t;

  signal pre_ci : prefetch_cpu_i_t;
  signal pre_co : prefetch_cpu_o_t;
  signal pre_mi : prefetch_mem_i_t;
  signal pre_mo : prefetch_mem_o_t;

  function to_data_o(p : prefetch_mem_o_t)
  return cpu_data_o_t is
    variable r : cpu_data_o_t;
  begin
    r.en := p.en;
    r.rd := p.en;
    r.wr := '0';
    r.a := p.a;
    r.we := "0000";
    r.d := (others => '0');
    return r;
  end function to_data_o;
begin
  pre_ci.en <= cpu0_ibus_o.en;
  pre_ci.a <= cpu0_ibus_o.a & "0";
  cpu0_ibus_i.ack <= pre_co.ack;
  cpu0_ibus_i.d <= pre_co.d;

  prefetcher: prefetch port map (
    rst => rst, clk => clk,
    ca => pre_ci, cy => pre_co,
    ma => pre_mi, my => pre_mo);

  -- connect prefetcher to instruction bus ports
  pre_mi.ack <= instr_dbus_i.ack;
  pre_mi.d <= instr_dbus_i.d;
  instr_dbus_o <= to_data_o(pre_mo);
  
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
