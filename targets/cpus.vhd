library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.cpu2j0_pack.all;
use work.data_bus_pack.all;
use work.attr_pack.all;
use work.config.all;

entity cpus is
  port (
    clk : in std_logic;
    rst : in std_logic;

    cpu0_periph_dbus_o : out cpu_data_o_t;
    cpu0_periph_dbus_i : in  cpu_data_i_t;

    cpu0_ddr_ibus_o : out cpu_instruction_o_t;
    cpu0_ddr_ibus_i : in  cpu_instruction_i_t;

    cpu0_ddr_dbus_o : out cpu_data_o_t;
    cpu0_ddr_dbus_i : in cpu_data_i_t;

    cpu0_mem_lock : out std_logic;

    cpu1_periph_dbus_o : out cpu_data_o_t;
    cpu1_periph_dbus_i : in cpu_data_i_t;

    cpu1_ddr_ibus_o : out cpu_instruction_o_t;
    cpu1_ddr_ibus_i : in  cpu_instruction_i_t;

    cpu1_ddr_dbus_o : out cpu_data_o_t;
    cpu1_ddr_dbus_i : in  cpu_data_i_t;

    cpu1_mem_lock : out std_logic;

    irqs : in std_logic_vector(7 downto 0);

    debug_i : in  cpu_debug_i_t;
    debug_o : out cpu_debug_o_t;

    rtc_sec : out std_logic_vector(63 downto 0);
    rtc_nsec : out std_logic_vector(31 downto 0));
-- synopsys translate_off
  group global_sigs : global_ports(
    cpu0_periph_dbus_o,
    cpu0_periph_dbus_i,
    cpu0_ddr_ibus_o,
    cpu0_ddr_ibus_i,
    cpu0_ddr_dbus_o,
    cpu0_ddr_dbus_i,
    cpu0_mem_lock,
    cpu1_periph_dbus_o,
    cpu1_periph_dbus_i,
    cpu1_ddr_ibus_o,
    cpu1_ddr_ibus_i,
    cpu1_ddr_dbus_o,
    cpu1_ddr_dbus_i,
    cpu1_mem_lock,
    irqs,
    rtc_sec,
    rtc_nsec,
    debug_i,
    debug_o);
-- synopsys translate_on
end entity;

architecture one_cpu of cpus is
  signal instr_bus_o : instr_bus_o_t;
  signal instr_bus_i : instr_bus_i_t;

  signal data_bus_o : data_bus_o_t;
  signal data_bus_i : data_bus_i_t;
begin

  cpu0 : entity work.cpu_core(arch)
    generic map (
      bus_period => CFG_BUS_PERIOD)
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
      irq_i => irqs,
      rtc_sec => rtc_sec,
      rtc_nsec => rtc_nsec);

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

  sram : entity work.memory_fpga(struc)
    port map (
      clk => clk,
      ibus_i => instr_bus_o(DEV_SRAM),
      ibus_o => instr_bus_i(DEV_SRAM),
      db_i => data_bus_o(DEV_SRAM),
      db_o => data_bus_i(DEV_SRAM));

end architecture;
