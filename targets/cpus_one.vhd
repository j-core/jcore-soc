
architecture one_cpu of cpus is
  signal instr_bus_o : instr_bus_o_t;
  signal instr_bus_i : instr_bus_i_t;

  signal data_bus_o : data_bus_o_t;
  signal data_bus_i : data_bus_i_t;
begin

  cpu0 : cpu_core
    port map (
      clk => clk,
      rst => rst,
      instr_bus_o => instr_bus_o,
      instr_bus_i => instr_bus_i,
      data_bus_lock => cpu0_mem_lock,
      data_bus_o => data_bus_o,
      data_bus_i => data_bus_i,
      debug_o => debug_o,
      debug_i => debug_i,
      event_o => cpu0_event_o,
      event_i => cpu0_event_i,
      data_master_en => cpu0_data_master_en,
      data_master_ack => cpu0_data_master_ack);

  cpu0_periph_dbus_o <= data_bus_o(DEV_PERIPH);
  data_bus_i(DEV_PERIPH) <= cpu0_periph_dbus_i;

  cpu0_ddr_ibus_o <= instr_bus_o(DEV_DDR);
  instr_bus_i(DEV_DDR) <= cpu0_ddr_ibus_i;

  cpu0_ddr_dbus_o <= data_bus_o(DEV_DDR);
  data_bus_i(DEV_DDR) <= cpu0_ddr_dbus_i;

  cpu1_periph_dbus_o <= NULL_DATA_O;
  cpu1_ddr_ibus_o <= NULL_INST_O;
  cpu1_ddr_dbus_o <= NULL_DATA_O;
  cpu1_mem_lock <= '0';
  cpu1_event_o <= (lvl => (others => '0'),
                   others => '0');
  cpu1_data_master_en <= '0';
  cpu1_data_master_ack <= '0';

  sram : entity work.memory_fpga(struc)
    port map (
      clk => clk,
      ibus_i => instr_bus_o(DEV_SRAM),
      ibus_o => instr_bus_i(DEV_SRAM),
      db_i => data_bus_o(DEV_SRAM),
      db_o => data_bus_i(DEV_SRAM));

  -- loop back DEV_CPU area
  data_bus_i(DEV_CPU) <= loopback_bus(data_bus_o(DEV_CPU));

end architecture;

configuration one_cpu_fpga of cpus is
  for one_cpu
    for all : cpu_core
      use entity work.cpu_core(arch);
      for arch
        for u_cpu : cpu
          use configuration work.cpu_fpga;
        end for;
      end for;
    end for;
  end for;
end configuration;
