library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.cpu2j0_pack.all;
use work.data_bus_pack.all;
use work.attr_pack.all;
use work.config.all;
use work.cpu_core_pack.all;

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

    debug_i : in  cpu_debug_i_t;
    debug_o : out cpu_debug_o_t;

    cpu0_data_master_en : out std_logic;
    cpu1_data_master_en : out std_logic;
    cpu0_data_master_ack : out std_logic;
    cpu1_data_master_ack : out std_logic;

    cpu0_event_o : out cpu_event_o_t;
    cpu0_event_i : in cpu_event_i_t;
    cpu1_event_o : out cpu_event_o_t;
    cpu1_event_i : in cpu_event_i_t);
-- synopsys translate_off
  group global_sigs : global_ports(
    cpu0_ddr_ibus_o,
    cpu0_ddr_ibus_i,
    cpu0_ddr_dbus_o,
    cpu0_ddr_dbus_i,
    cpu0_mem_lock,
    cpu1_ddr_ibus_o,
    cpu1_ddr_ibus_i,
    cpu1_ddr_dbus_o,
    cpu1_ddr_dbus_i,
    cpu1_mem_lock,
    debug_i,
    debug_o,
    cpu0_data_master_en,
    cpu1_data_master_en,
    cpu0_data_master_ack,
    cpu1_data_master_ack,
    cpu0_event_o,
    cpu0_event_i,
    cpu1_event_o,
    cpu1_event_i);
  group cpu0 : peripheral_bus(
    cpu0_periph_dbus_o,
    cpu0_periph_dbus_i);
  group cpu1 : peripheral_bus(
    cpu1_periph_dbus_o,
    cpu1_periph_dbus_i);
-- synopsys translate_on
end entity;
