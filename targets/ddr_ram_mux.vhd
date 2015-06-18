-- Copyright (c) 2015, Smart Energy Instruments Inc.
-- All rights reserved.  For details, see COPYING in the top level directory.

-- This entity combines the 5 buses that talk to DDR RAM: an instruction and
-- data bus from each CPU and a data bus from the DMA controller (currently
-- commented out). Different architectures of this entity support different
-- single or dual CPUs and different caching strategies.
-- 
library ieee;
use ieee.std_logic_1164.all;

use work.cpu2j0_pack.all;
use work.attr_pack.all;
use work.data_bus_pack.all;
--use work.dma_pack.all;

entity ddr_ram_mux is
  port (
    clk : in std_logic;
    clk_ddr : in std_logic;
    rst : in std_logic;

    -- 5 buses from masters reading and writing DDR RAM
    cpu0_ibus_o : in  cpu_instruction_o_t;
    cpu0_ibus_i : out cpu_instruction_i_t;

    cpu0_dbus_o : in  cpu_data_o_t;
    cpu0_dbus_i : out cpu_data_i_t;

    cpu0_mem_lock : in std_logic;

    cpu1_ibus_o : in  cpu_instruction_o_t;
    cpu1_ibus_i : out cpu_instruction_i_t;

    cpu1_dbus_o : in  cpu_data_o_t;
    cpu1_dbus_i : out cpu_data_i_t;

    cpu1_mem_lock : in std_logic;

    --dma_dbus_o : in  bus_ddrri_o_t;
    --dma_dbus_i : out bus_ddrri_i_t;

    -- cache control lines
    icache0_ctrl : in cache_ctrl_t;
    icache1_ctrl : in cache_ctrl_t;
    dcache_ctrl  : in cache_ctrl_t;
    cache01sel_ctrl_temp : in std_logic; -- temporary signal 
         -- (1) to confirm one cpu two cache logic amount,
         -- (2) to verify two dcache snoop

    -- TODO: does underlying bus mux need control lines to determine priority?

    -- aggregated bus going to the ddr controller
    ddr_bus_o : out cpu_data_o_t;
    ddr_bus_i : in cpu_data_i_t);

  attribute sei_port_global_name of cpu0_ibus_o : signal is "cpu0_ddr_ibus_o";
  attribute sei_port_global_name of cpu0_ibus_i : signal is "cpu0_ddr_ibus_i";
  attribute sei_port_global_name of cpu0_dbus_o : signal is "cpu0_ddr_dbus_o";
  attribute sei_port_global_name of cpu0_dbus_i : signal is "cpu0_ddr_dbus_i";
  attribute sei_port_global_name of cpu1_ibus_o : signal is "cpu1_ddr_ibus_o";
  attribute sei_port_global_name of cpu1_ibus_i : signal is "cpu1_ddr_ibus_i";
  attribute sei_port_global_name of cpu1_dbus_o : signal is "cpu1_ddr_dbus_o";
  attribute sei_port_global_name of cpu1_dbus_i : signal is "cpu1_ddr_dbus_i";
  -- synopsys translate_off
  group global_sigs : global_ports(
    clk_ddr,
    icache0_ctrl,
    icache1_ctrl,
    dcache_ctrl,
    cache01sel_ctrl_temp,
    ddr_bus_o,
    ddr_bus_i,
    cpu0_mem_lock,
    cpu1_mem_lock);
-- synopsys translate_on
end entity;

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
  --dma_dbus_i <= loopback_bus(dma_dbus_o);
end architecture;
