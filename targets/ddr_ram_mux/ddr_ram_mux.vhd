-- This entity combines the 5 buses that talk to DDR RAM: an instruction and
-- data bus from each CPU and a data bus from the DMA controller. Different
-- architectures of this entity support different single or dual CPUs and
-- different caching strategies.
-- 
library ieee;
use ieee.std_logic_1164.all;

use work.cpu2j0_pack.all;
use work.attr_pack.all;
use work.data_bus_pack.all;
use work.dma_pack.all;

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

    dma_dbus_o : in  bus_ddr_o_t;
    dma_dbus_i : out bus_ddr_i_t;

    -- cache control lines
    icache0_ctrl : in cache_ctrl_t;
    icache1_ctrl : in cache_ctrl_t;
    dcache0_ctrl  : in cache_ctrl_t;
    dcache1_ctrl  : in cache_ctrl_t;
    cache01sel_ctrl_temp : in std_logic; -- temporary signal 
         -- (1) to confirm one cpu two cache logic amount,
         -- (2) to verify two dcache snoop

    -- TODO: does underlying bus mux need control lines to determine priority?

    -- aggregated bus going to the ddr controller
    ddr_bus_o : out cpu_data_o_t;
    ddr_bus_i : in cpu_data_i_t;
    ddr_burst : out std_logic);

  attribute sei_port_global_name of cpu0_ibus_o : signal is "cpu0_ddr_ibus_o";
  attribute sei_port_global_name of cpu0_ibus_i : signal is "cpu0_ddr_ibus_i";
  attribute sei_port_global_name of cpu0_dbus_o : signal is "cpu0_ddr_dbus_o";
  attribute sei_port_global_name of cpu0_dbus_i : signal is "cpu0_ddr_dbus_i";
  attribute sei_port_global_name of cpu1_ibus_o : signal is "cpu1_ddr_ibus_o";
  attribute sei_port_global_name of cpu1_ibus_i : signal is "cpu1_ddr_ibus_i";
  attribute sei_port_global_name of cpu1_dbus_o : signal is "cpu1_ddr_dbus_o";
  attribute sei_port_global_name of cpu1_dbus_i : signal is "cpu1_ddr_dbus_i";
  attribute sei_port_global_name of clk_ddr : signal is "clk_mem";
-- synopsys translate_off
  group global_sigs : global_ports(
    dma_dbus_o,
    dma_dbus_i,
    icache0_ctrl,
    icache1_ctrl,
    dcache0_ctrl,
    dcache1_ctrl,
    cache01sel_ctrl_temp,
    ddr_bus_o,
    ddr_bus_i,
    ddr_burst,
    cpu0_mem_lock,
    cpu1_mem_lock);
-- synopsys translate_on
end entity;
